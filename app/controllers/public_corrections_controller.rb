class PublicCorrectionsController < ApplicationController
  skip_before_action :require_maestro_subscription
  before_action :set_activity, except: %i[gate enter]
  layout "correction"

  def gate
  end

  def enter
    pin = params[:pin].to_s.gsub(/\D/, "")
    activity = Activity.find_by(correction_pin: pin)
    if activity
      redirect_to gabarito_path(activity.correction_token)
      return
    end

    redirect_to correction_gate_path, alert: "Este código não confere. Digite os 6 números da tela do computador."
  end

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
    @assignments_by_student = @activity.exam_assignments.index_by(&:student_id)
    @assignment = @student && @assignments_by_student[@student.id]
    @presented = Activities::ExamAssigner.new(@activity).presented_for(@student)
    @lira_ready = Lira.llm_enabled?
    objective_items = @items.select(&:objective?)
    @bubble_question_count = objective_items.size
    letter_count = objective_items.map { |item| item.choice_pairs.size }.max.to_i
    @bubble_letter_count = letter_count.between?(2, 5) ? letter_count : 5
    apply_photo_preview
  end

  def scan_card
    student = @activity.lesson.classroom.students.find_by(id: params[:student_id])
    unless student
      redirect_to gabarito_path(@activity.correction_token), alert: "Escolha o aluno antes de fotografar o cartão."
      return
    end

    upload = params[:card]
    unless upload.respond_to?(:original_filename)
      redirect_to gabarito_aluno_path(@activity.correction_token, student),
                  alert: "Fotografe o cartão-resposta com as bolhas pintadas."
      return
    end

    if upload.size.to_i > 10.megabytes
      redirect_to gabarito_aluno_path(@activity.correction_token, student),
                  alert: "A foto passou de 10 MB. Tire outra, mais perto do cartão."
      return
    end

    result = Activities::AnswerCardIntake.new(
      @activity,
      professor: @activity.lesson.professor
    ).scan_for_student!(
      upload,
      student: student,
      overwrite: true,
      position_answers: params[:bubble_answers],
      stable: params[:bubble_stable].to_s == "1"
    )

    case result.status
    when :launched
      session.delete(:gabarito_preview)
      redirect_to gabarito_aluno_path(@activity.correction_token, student, ok: 1),
                  notice: "Nota #{format('%.1f', result.score.to_f).tr('.', ',')} lançada."
    when :review
      session[:gabarito_preview] = { "student_id" => student.id, "answers" => result.answers }
      redirect_to gabarito_aluno_path(@activity.correction_token, student),
                  alert: "Confira a folha: verde é a certa desta versão e o X vermelho é a letra lida. Acerte o que estiver diferente e lance a nota."
    when :lira_off
      redirect_to gabarito_aluno_path(@activity.correction_token, student),
                  alert: "Não li as bolhas neste cartão. Marque as letras na tela."
    else
      session.delete(:gabarito_preview)
      redirect_to gabarito_aluno_path(@activity.correction_token, student),
                  alert: "Não li bolhas nítidas. Enquadre o cartão inteiro ou marque as letras na tela."
    end
  end

  def grade
    student = @activity.lesson.classroom.students.find(params[:student_id])
    answers = params[:answers].presence || {}
    answers = answers.to_unsafe_h if answers.respond_to?(:to_unsafe_h)
    assignment = @activity.exam_assignments.find_by(student: student)
    score = Activities::Grader.new(@activity, assignment: assignment).score(answers)

    submission = ActivitySubmission.find_or_initialize_by(
      activity: @activity,
      student: student
    )
    submission.professor = @activity.lesson.professor
    submission.answers = answers
    submission.score = score
    submission.submitted_on ||= Date.current

    if submission.save
      session.delete(:gabarito_preview)
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

  def apply_photo_preview
    preview = session[:gabarito_preview]
    return unless @student && preview && preview["student_id"].to_i == @student.id

    @answers = @answers.stringify_keys.merge((preview["answers"] || {}).stringify_keys)
    @photo_review = true
  end
end
