class AttendanceRecord < ApplicationRecord
  belongs_to :professor
  belongs_to :enrollment
  belongs_to :lesson, optional: true

  has_one :student, through: :enrollment
  has_one :classroom, through: :enrollment

  before_validation :assign_lesson_from_date

  enum :status, {
    present: "present",
    absent: "absent",
    justified: "justified",
    late: "late"
  }

  validates :attendance_date, presence: true
  validates :status, presence: true
  validates :enrollment_id,
            uniqueness: {
              scope: %i[attendance_date lesson_id],
              message: "já possui frequência lançada para esta aula"
            }

  validate :enrollment_belongs_to_professor

  private

  def assign_lesson_from_date
    return if lesson_id.present?
    return if enrollment.blank? || attendance_date.blank?

    self.lesson_id = Lesson.where(
      classroom_id: enrollment.classroom_id,
      lesson_date: attendance_date,
      professor_id: professor_id
    ).order(:created_at).pick(:id)
  end


  def enrollment_belongs_to_professor
    return if enrollment.blank? || professor.blank?

    return if enrollment.professor_id == professor_id

    errors.add(:enrollment, "não pertence ao professor atual")
  end
end
