class Student < ApplicationRecord
  belongs_to :professor

  has_many :enrollments, dependent: :restrict_with_error
  has_many :classrooms, through: :enrollments
  has_many :attendance_records, through: :enrollments

  has_many :activity_recipients, dependent: :destroy

  has_one_attached :photo

  belongs_to :course, optional: true

  # Associação antiga mantida apenas para preservar a coluna classroom_id
  # existente na tabela students.
  belongs_to :legacy_classroom,
             class_name: "Classroom",
             foreign_key: :classroom_id,
             optional: true

  validates :name, presence: true

  validates :registration_number,
            uniqueness: {
              scope: :professor_id,
              allow_blank: true
            }

  validate :course_belongs_to_professor
  validate :legacy_classroom_belongs_to_professor

  private

  def course_belongs_to_professor
    return if course.blank? || professor.blank?
    return if course.professor_id == professor_id

    errors.add(:course, "não pertence ao professor atual")
  end

  def legacy_classroom_belongs_to_professor
    return if legacy_classroom.blank? || professor.blank?
    return if legacy_classroom.professor_id == professor_id

    errors.add(:classroom, "não pertence ao professor atual")
  end
end