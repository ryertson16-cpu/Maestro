class PublicCorrectionsController < ApplicationController
  skip_before_action :require_maestro_subscription
  before_action :set_activity
  layout "correction"

  def show
    @items = @activity.activity_questions.with_attached_image
    @classroom = @activity.lesson.classroom
    @students = @classroom.students.order(:name)
    @student = @students.find_by(id: params[:student_id]) if params[:student_id].present?
    @student ||= @students.find_by(id: params[:s]) if params[:s].present?
    @submission = @student && @activity.activity_submissions.find_by(student: @student)
    @answers = @submission&.answers.presence || {}
    @score = @submission&.score
    @just_graded = params[:ok].present?
  end

  def grade
    student = @activity.lesson.classroom.students.find(params[:student_id])
    answers = params[:answers].presence || {}
    answers = answers.to_unsafe_h if answers.respond_to?(:to_unsafe_h)
    score = Activities::Grader.new(@activity).score(answers)

    submission = ActivitySubmission.find_or_initialize_by(
      activity: @activity,
      student: student
    )
    submission.professor = @activity.lesson.professor
    submission.answers = answers
    submission.score = score
    submission.submitted_on ||= Date.current

    if submission.save
      redirect_to gabarito_aluno_path(@activity.correction_token, student, ok: 1),
                  notice: "Nota #{format('%.1f', score).tr('.', ',')} lançada."
    else
      redirect_to gabarito_aluno_path(@activity.correction_token, student),
                  alert: submission.errors.full_messages.to_sentence
    end
  end

  private

  def set_activity
    @activity = Activity.find_by(correction_token: params[:token].to_s)
    return if @activity

    render :missing, status: :not_found
  end
end
