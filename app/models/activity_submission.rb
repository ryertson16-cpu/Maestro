class ActivitySubmission < ApplicationRecord
  belongs_to :activity
  belongs_to :student
  belongs_to :professor

  validates :activity_id,
            uniqueness: {
              scope: :student_id,
              message: "já possui um registro para este aluno"
            }

  validates :score,
            numericality: {
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 10
            },
            allow_nil: true

  validate :student_belongs_to_activity_classroom

  def status
    return :delivered if submitted_on.present? &&
                          submitted_on <= activity.due_date

    return :delivered_late if submitted_on.present? &&
                               submitted_on > activity.due_date

    return :not_delivered if Date.current > activity.due_date

    :in_progress
  end

  def status_label
    {
      delivered: "Entregue",
      delivered_late: "Entregue com Atraso",
      in_progress: "Em Andamento",
      not_delivered: "Não Entregou"
    }.fetch(status)
  end

  private

  def student_belongs_to_activity_classroom
    return if activity.blank? || student.blank?

    classroom = activity.lesson.classroom

    return if classroom.students.exists?(student.id)

    errors.add(
      :student,
      "não pertence à turma desta atividade"
    )
  end
end