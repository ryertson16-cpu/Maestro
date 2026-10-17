class Enrollment < ApplicationRecord
  STATUSES = {
    "active" => "Ativa",
    "finished" => "Encerrada",
    "cancelled" => "Cancelada",
    "transferred" => "Remanejada"
  }.freeze

  belongs_to :professor
  belongs_to :student
  belongs_to :classroom

  has_many :attendance_records, dependent: :restrict_with_error

  has_many :activity_submissions,
           dependent: :destroy

  validates :enrolled_on, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES.keys }

  def active_in_classroom?
    status.to_s == "active"
  end

  def status_label
    STATUSES.fetch(status.to_s, status)
  end

  def caderno_tag
    return if active_in_classroom?
    return "Remanejado" if status.to_s == "transferred"

    "Inativo"
  end

  validates :student_id,
            uniqueness: {
              scope: :classroom_id,
              message: "já está matriculado nesta turma"
            }

  validate :student_belongs_to_professor
  validate :classroom_belongs_to_professor

  private

  def student_belongs_to_professor
    return if student.blank? || professor.blank?
    return if student.professor_id == professor_id

    errors.add(:student, "não pertence ao professor atual")
  end

  def classroom_belongs_to_professor
    return if classroom.blank? || professor.blank?
    return if classroom.professor_id == professor_id

    errors.add(:classroom, "não pertence ao professor atual")
  end
end