class RecoveryGrade < ApplicationRecord
  belongs_to :student
  belongs_to :classroom
  belongs_to :professor

  validates :bimester,
            inclusion: {
              in: 1..4
            }

  validates :score,
            numericality: {
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 10
            }

  validates :student_id,
            uniqueness: {
              scope: %i[classroom_id bimester],
              message: "já possui recuperação neste bimestre"
            }

  validate :student_must_belong_to_classroom

  private

  def student_must_belong_to_classroom
    return if classroom.blank? || student.blank?

    return if classroom.students.exists?(student.id)

    errors.add(
      :student,
      "não pertence à turma informada"
    )
  end
end