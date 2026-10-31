class ActivityPendingCardsController < ApplicationController
  before_action :authenticate_professor!
  before_action :set_card

  def assign
    student = classroom_students.find_by(id: params[:student_id])
    unless student
      redirect_to assemble_activity_path(@activity),
                  alert: "Escolha o aluno deste cartão."
      return
    end

    result = Activities::AnswerCardIntake.new(@activity, professor: current_professor).apply!(
      @card,
      student: student
    )

    redirect_to results_activity_path(@activity),
                notice: assign_notice(result, student)
  end

  def destroy
    filename = @card.filename
    @card.destroy!
    redirect_to assemble_activity_path(@activity),
                notice: "#{filename} saiu da conferência."
  end

  private

  def set_card
    @activity = Activity
                .joins(:lesson)
                .where(lessons: { classroom_id: current_professor.classrooms.select(:id) })
                .find(params[:activity_id])
    @classroom = current_professor.classrooms.find(@activity.lesson.classroom_id)
    @card = @activity.pending_cards.find(params[:id])
  end

  def classroom_students
    @classroom.students
  end

  def assign_notice(result, student)
    case result
    when :already_scored
      "#{student.name} já tem nota nesta atividade. Nada foi alterado."
    when :launched
      submission = ActivitySubmission.find_by(activity: @activity, student: student)
      "Nota de #{student.name}: #{format('%.1f', submission.score).tr('.', ',')}."
    else
      "Não foi possível lançar este cartão."
    end
  end
end
