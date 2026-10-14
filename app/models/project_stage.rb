class ProjectStage < ApplicationRecord
  STATUSES = {
    "pending" => "Pendente",
    "partial" => "Parcial",
    "done" => "Concluída"
  }.freeze

  belongs_to :project
  belongs_to :lesson, optional: true
  has_many_attached :evidences

  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES.keys }
  validate :lesson_belongs_to_project

  def status_label
    STATUSES.fetch(status, status)
  end

  def overdue?
    due_on.present? && due_on < Date.current && status != "done"
  end

  private

  def lesson_belongs_to_project
    return if lesson.blank? || project.blank?

    if project.classrooms.any?
      unless project.classrooms.include?(lesson.classroom)
        errors.add(:lesson, "precisa ser de uma turma vinculada ao projeto")
      end
    elsif lesson.professor_id != project.professor_id
      errors.add(:lesson, "não pertence ao professor atual")
    end
  end
end
