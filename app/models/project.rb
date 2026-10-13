class Project < ApplicationRecord
  KINDS = {
    "classroom" => "Projeto de turma",
    "professor_nota_10" => "Professor Nota 10",
    "school_nota_10" => "Escola Nota 10",
    "other" => "Outro"
  }.freeze

  AUDIENCES = {
    "one_classroom" => "Uma turma",
    "several_classrooms" => "Várias turmas",
    "school" => "Escola",
    "professor" => "Somente o professor"
  }.freeze

  STATUSES = {
    "draft" => "Rascunho",
    "active" => "Em andamento",
    "completed" => "Concluído",
    "archived" => "Arquivado"
  }.freeze

  belongs_to :professor
  has_many :project_classrooms, dependent: :destroy
  has_many :classrooms, through: :project_classrooms
  has_many :project_stages, -> { order(:position, :id) }, dependent: :destroy

  validates :title, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS.keys }
  validates :audience, presence: true, inclusion: { in: AUDIENCES.keys }
  validates :status, presence: true, inclusion: { in: STATUSES.keys }
  validates :kind_other, presence: true, if: -> { kind == "other" }
  validate :classrooms_match_audience
  validate :classrooms_belong_to_professor

  after_create :seed_stages

  def kind_label
    return kind_other.presence || KINDS["other"] if kind == "other"

    KINDS.fetch(kind, kind)
  end

  def audience_label
    AUDIENCES.fetch(audience, audience)
  end

  def status_label
    STATUSES.fetch(status, status)
  end

  def next_stage
    project_stages.find { |stage| stage.status != "done" } || project_stages.last
  end

  def overdue_stages
    project_stages.select(&:overdue?)
  end

  def progress
    return 0 if project_stages.none?

    done = project_stages.count { |stage| stage.status == "done" }
    ((done.to_f / project_stages.size) * 100).round
  end

  def students
    Enrollment
      .where(professor: professor, classroom: classrooms, status: "active")
      .includes(:student)
      .joins(:student)
      .order("students.name")
      .map(&:student)
      .uniq
  end

  def self.overdue_for(professor)
    joins(:project_stages)
      .where(professor: professor)
      .where.not(status: %w[completed archived])
      .where(project_stages: { status: %w[pending partial] })
      .where("project_stages.due_on < ?", Date.current)
      .distinct
      .includes(:project_stages, :classrooms)
      .order(:title)
  end

  private

  def classrooms_match_audience
    count = classroom_ids.compact.uniq.size

    case audience
    when "one_classroom"
      errors.add(:classrooms, "selecione uma turma") unless count == 1
    when "several_classrooms"
      errors.add(:classrooms, "selecione pelo menos duas turmas") if count < 2
    end
  end

  def classrooms_belong_to_professor
    return if professor.blank?

    extra = Classroom.where(id: classroom_ids).where.not(professor_id: professor_id)
    return if extra.none?

    errors.add(:classrooms, "não pertencem ao professor atual")
  end

  def seed_stages
    return if project_stages.exists?

    Projects::StageCatalog.for(kind).each.with_index(1) do |attrs, position|
      project_stages.create!(attrs.merge(position: position))
    end
  end
end
