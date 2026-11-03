class Student < ApplicationRecord
  belongs_to :professor

  has_many :enrollments, dependent: :restrict_with_error
  has_many :classrooms, through: :enrollments
  has_many :attendance_records, through: :enrollments

  has_many :activity_recipients, dependent: :destroy
  has_many :activity_submissions, dependent: :delete_all
  has_many :activity_exam_assignments, dependent: :delete_all
  has_many :activity_pending_cards, dependent: :nullify
  has_many :enem_simulado_sheets, dependent: :destroy
  has_many :council_notes, dependent: :delete_all
  has_many :student_occurrences, dependent: :delete_all
  has_many :recovery_grades, dependent: :delete_all

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

  def destroy_with_history!
    transaction do
      ActivityExamAssignment.where(student_id: id).delete_all
      ActivityPendingCard.where(student_id: id).update_all(student_id: nil)
      ActivitySubmission.where(student_id: id).delete_all
      ActivityRecipient.where(student_id: id).delete_all
      CouncilNote.where(student_id: id).delete_all
      StudentOccurrence.where(student_id: id).delete_all
      RecoveryGrade.where(student_id: id).delete_all
      EnemSimuladoSheet.where(student_id: id).find_each do |sheet|
        sheet.card_pdf.purge if sheet.card_pdf.attached?
        sheet.delete
      end

      enrollment_ids = Enrollment.where(student_id: id).pluck(:id)
      AttendanceRecord.where(enrollment_id: enrollment_ids).delete_all
      Enrollment.where(student_id: id).delete_all

      photo.purge if photo.attached?
      delete
    end
  end

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