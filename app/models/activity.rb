class Activity < ApplicationRecord
  BIMESTERS = {
    1 => "1º Bimestre",
    2 => "2º Bimestre",
    3 => "3º Bimestre",
    4 => "4º Bimestre"
  }.freeze

  ADAPTATION_KINDS = {
    "reduced" => "Reduzida",
    "oral" => "Oral",
    "supported" => "Com apoio",
    "extra_time" => "Tempo extra",
    "format" => "Formato diferente",
    "criteria" => "Critério diferente"
  }.freeze

  GRADE_MODES = {
    "replaces" => "Substitui a atividade da turma",
    "complements" => "Complementa (não entra na média)"
  }.freeze

  belongs_to :lesson
  belongs_to :parent_activity,
             class_name: "Activity",
             optional: true

  has_many :adapted_versions,
           class_name: "Activity",
           foreign_key: :parent_activity_id,
           dependent: :destroy

  has_many :activity_submissions,
           dependent: :destroy

  has_many :activity_recipients,
           dependent: :destroy

  has_many :recipient_students,
           through: :activity_recipients,
           source: :student

  has_many :activity_questions,
           -> { order(:position) },
           dependent: :destroy

  has_many :pending_cards,
           class_name: "ActivityPendingCard",
           dependent: :destroy

  has_many :exam_assignments,
           class_name: "ActivityExamAssignment",
           dependent: :delete_all

  has_one :enem_simulado, dependent: :nullify

  before_validation :ensure_correction_token, on: :create

  validates :title,
            presence: true

  validates :activity_type,
            presence: true,
            inclusion: {
              in: Lesson::ACTIVITY_TYPES
            }

  validates :due_date,
            presence: true

  validates :maximum_score,
            numericality: {
              greater_than_or_equal_to: 0
            },
            allow_blank: true

  validates :bimester,
            presence: true,
            inclusion: {
              in: BIMESTERS.keys
            }

  validates :weight,
            presence: true,
            numericality: {
              greater_than: 0
            }

  validates :adaptation_kind,
            inclusion: { in: ADAPTATION_KINDS.keys },
            if: :adapted?

  validates :grade_mode,
            inclusion: { in: GRADE_MODES.keys },
            if: :adapted?

  validate :due_date_cannot_be_before_lesson_date
  validate :adapted_has_recipients
  validate :parent_is_regular

  scope :regular, -> { where(adapted: false) }
  scope :adapted, -> { where(adapted: true) }

  def bimester_label
    BIMESTERS.fetch(bimester)
  end

  def recovery_eligible?
    title.to_s.match?(/\bprova\b/i)
  end

  def regular?
    !adapted?
  end

  def replaces?
    adapted? && grade_mode.to_s == "replaces"
  end

  def complements?
    adapted? && grade_mode.to_s == "complements"
  end

  def adaptation_kind_label
    ADAPTATION_KINDS[adaptation_kind.to_s]
  end

  def grade_mode_label
    GRADE_MODES[grade_mode.to_s]
  end

  def assigned_to?(student)
    return true if regular?

    recipient_student_ids.include?(student.id)
  end

  def replacing_version_for(student)
    return if adapted?

    adapted_versions.find do |version|
      version.replaces? && version.assigned_to?(student)
    end
  end

  def required_delivery_for?(student)
    return false unless assigned_to?(student)
    return false if regular? && replacing_version_for(student).present?

    true
  end

  def assembled?
    activity_questions.any?
  end

  def discard_with_generated_data!
    lesson_record = lesson
    generated = generated_vehicle_lesson?

    self.class.transaction do
      adapted_versions.find_each(&:destroy!)
      destroy!
      leftover = lesson_record.activities.reload
      if leftover.none?
        if generated
          lesson_record.destroy!
        else
          lesson_record.update!(has_activity: false)
        end
      end
    end
  end

  def generated_vehicle_lesson?
    instructions.to_s.match?(/importada do question[aá]rio online|simulado enem/i)
  end

  def ensure_correction_token!
    ensure_correction_token
    save! if correction_token_changed? || !persisted?
    correction_token
  end

  def correction_path_token
    ensure_correction_token!
  end

  def counts_toward_average_for?(student)
    return false unless assigned_to?(student)
    return false if complements?
    return false if regular? && replacing_version_for(student).present?

    true
  end

  def submission_for_average(student, submissions_by_pair = nil)
    source = replacing_version_for(student) || self
    if submissions_by_pair
      submissions_by_pair[[student.id, source.id]]
    else
      source.activity_submissions.find { |item| item.student_id == student.id }
    end
  end

  private

  def ensure_correction_token
    self.correction_token = SecureRandom.base58(24) if correction_token.blank?
  end

  def due_date_cannot_be_before_lesson_date
    return if due_date.blank? || lesson.blank?
    return if lesson.lesson_date.blank?
    return if due_date >= lesson.lesson_date

    errors.add(
      :due_date,
      "não pode ser anterior à data da aula"
    )
  end

  def adapted_has_recipients
    return unless adapted?
    return if activity_recipients.any? || recipient_students.any?

    errors.add(:recipient_students, "escolha pelo menos um aluno")
  end

  def parent_is_regular
    return if parent_activity.blank?
    return unless parent_activity.adapted?

    errors.add(:parent_activity, "precisa ser uma atividade da turma")
  end
end
