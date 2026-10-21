class Lesson < ApplicationRecord
  ACTIVITY_KIND_CHOICES = [
    "Lista de exercícios",
    "Atividade avaliativa",
    "Prática experimental",
    "Prova",
    "Simulado ENEM",
    "Estudo dirigido",
    "Trabalho em grupo",
    "Relatório",
    "Questionário",
    "Seminário",
    "Pesquisa",
    "Oficina",
    "Redação",
    "Visita técnica",
    "Projeto"
  ].freeze

  ACTIVITY_OTHER_TYPES = [
    "Apresentação",
    "Atividade em grupo",
    "Atividade individual",
    "Autoavaliação",
    "Debate",
    "Diário de aprendizagem",
    "Estudo de caso",
    "Exercício prático",
    "Mapa mental",
    "Portfólio",
    "Resenha",
    "Resumo",
    "Simulação",
    "Trabalho em dupla"
  ].freeze

  ACTIVITY_TYPES = (ACTIVITY_KIND_CHOICES + ACTIVITY_OTHER_TYPES).uniq.freeze

  def self.activity_type_grouped_options
    [
      ["Mais usadas", ACTIVITY_KIND_CHOICES],
      ["Outras", ACTIVITY_OTHER_TYPES]
    ]
  end

  belongs_to :professor
  belongs_to :classroom
  belongs_to :course, optional: true
  belongs_to :lesson_plan_template, optional: true

  has_many :attendance_records, dependent: :destroy
  has_many :siage_shipments, dependent: :nullify
  has_many :project_stages, dependent: :nullify

  has_one :activity,
          -> { where(adapted: false) },
          dependent: :destroy

  accepts_nested_attributes_for :activity,
                                reject_if: :all_blank,
                                allow_destroy: true
  
  has_many :activities, dependent: :destroy

  validates :lesson_date, presence: true
  validates :theme, presence: true
  validates :classroom, presence: true
  validates :professor, presence: true

  validates :course,
            presence: true,
            if: :course_required?

  validate :classroom_belongs_to_professor
  validate :course_belongs_to_professor

  before_validation :assign_siage_defaults
  before_validation :assign_default_theme
  after_create :link_existing_attendance_records
  before_destroy :destroy_adapted_activities_first

  private

  def link_existing_attendance_records
    AttendanceRecord
      .joins(:enrollment)
      .where(enrollments: { classroom_id: classroom_id })
      .where(attendance_date: lesson_date, lesson_id: nil, professor_id: professor_id)
      .update_all(lesson_id: id)
  end

  def destroy_adapted_activities_first
    activities.where.not(parent_activity_id: nil).find_each(&:destroy)
  end

  def assign_default_theme
    return if theme.present?

    course_name = course&.name.presence || "Componente curricular"
    self.theme = "Aula de #{course_name}"
  end

  def assign_siage_defaults
    linked = activity.presence || activities.first
    bimester = linked&.bimester

    if siage_period.blank? && bimester.present?
      self.siage_period = Siage.period_label(bimester)
    end

    if siage_class_mode.blank?
      self.siage_class_mode =
        if linked&.recovery_eligible? || linked&.activity_type.to_s.match?(/prova/i)
          "Avaliação"
        else
          "Aula"
        end
    end

    self.siage_class_type = "Avulso" if siage_class_type.blank?
  end

  def course_required?
    course_id.present?
  end

  def classroom_belongs_to_professor
    return if classroom.blank? || professor.blank?
    return if classroom.professor_id == professor_id

    errors.add(:classroom, "não pertence ao professor atual")
  end

  def course_belongs_to_professor
    return if course.blank? || professor.blank?
    return if course.professor_id == professor_id

    errors.add(:course, "não pertence ao professor atual")
  end
end