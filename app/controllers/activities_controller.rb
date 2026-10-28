class ActivitiesController < ApplicationController
  include CorrectionHost

  before_action :authenticate_professor!
  before_action :set_activity, except: :create

  def sheet
    @activity.ensure_correction_token!
    students = @classroom.students.order(:name)
    Activities::ExamAssigner.new(@activity).ensure!(students)
    pdf = Documents::ActivitySheet.new(
      professor: current_professor,
      activity: @activity,
      correction_url: gabarito_public_url(@activity),
      students: students,
      student_url: ->(student) { gabarito_student_url(@activity, student) }
    ).render

    send_data pdf,
              filename: sheet_filename,
              type: "application/pdf",
              disposition: "attachment"
  end

  def key_sheet
    @activity.ensure_correction_token!
    Activities::ExamAssigner.new(@activity).ensure!(@classroom.students.order(:name))
    pdf = Documents::ActivitySheet.new(
      professor: current_professor,
      activity: @activity,
      mode: :answer_key
    ).render

    send_data pdf,
              filename: sheet_filename(prefix: "gabarito-"),
              type: "application/pdf",
              disposition: "attachment"
  end

  def assemble
    @activity.ensure_correction_token!
    store_correction_host
    @correction_url = gabarito_public_url(@activity)
    @items = @activity.activity_questions.with_attached_image.includes(:question)
    @exam_assignments = Activities::ExamAssigner.new(@activity).ensure!(@classroom.students.order(:name))
    @courses = current_professor.courses.order(:name)
    @bank = current_professor
            .questions
            .with_attached_image
            .includes(:course)
            .search(params[:q])
            .order(updated_at: :desc)
    @bank = @bank.where(kind: params[:kind]) if params[:kind].present?
    if params[:course_id].present?
      @bank = @bank.where(course_id: params[:course_id])
    elsif @activity.lesson.course_id.present? && params[:q].blank? && params[:kind].blank?
      @bank = @bank.where(course_id: [nil, @activity.lesson.course_id])
    end
    used_ids = @items.filter_map(&:question_id)
    @bank = @bank.where.not(id: used_ids) if used_ids.any?
    @lira_ready = Lira.llm_enabled?
    @pending_cards = @activity.pending_cards.includes(:student)
    @students = @classroom.students.order(:name)
  end

  def open_gabarito
    @activity.ensure_correction_token!
    store_correction_host
    redirect_to gabarito_public_url(@activity), allow_other_host: true
  end

  def build_exam
    result = Activities::ExamBuilder.new(
      professor: current_professor,
      activity: @activity
    ).build!(
      topic: params[:topic],
      quantity: params[:quantity],
      course_id: params[:course_id],
      mix: params[:mix],
      difficulty: params[:difficulty]
    )

    redirect_to assemble_activity_path(@activity),
                notice: result.message
  end

  def correct
    @activity.ensure_correction_token!
    if params[:t].present? && params[:t].to_s != @activity.correction_token
      redirect_to assemble_activity_path(@activity), alert: "Este QR Code não confere com a atividade."
      return
    end

    redirect_to assemble_activity_path(@activity)
  end

  def grade
    student = current_professor.students.find(params[:student_id])
    answers = params[:answers].presence || {}
    answers = answers.to_unsafe_h if answers.respond_to?(:to_unsafe_h)
    assignment = @activity.exam_assignments.find_by(student: student)
    score = Activities::Grader.new(@activity, assignment: assignment).score(answers)

    submission = ActivitySubmission.find_or_initialize_by(
      activity: @activity,
      student: student
    )
    submission.professor = current_professor
    submission.answers = answers
    submission.score = score
    submission.submitted_on ||= Date.current

    if submission.save
      redirect_to assemble_activity_path(@activity),
                  notice: "Correção lançada: nota #{format('%.1f', score).tr('.', ',')}."
    else
      redirect_to assemble_activity_path(@activity),
                  alert: submission.errors.full_messages.to_sentence
    end
  end

  def scan_cards
    uploads = Array(params[:cards]).select { |item| item.respond_to?(:original_filename) }
    if uploads.empty?
      redirect_to assemble_activity_path(@activity),
                  alert: "Envie foto ou PDF do cartão-resposta."
      return
    end

    unless Lira.llm_enabled?
      redirect_to assemble_activity_path(@activity),
                  alert: "A leitura automática precisa do Maestro com OpenAI ou Gemini. No celular, marque as letras na tela."
      return
    end

    result = Activities::AnswerCardIntake.new(@activity, professor: current_professor).ingest!(uploads)
    redirect_to assemble_activity_path(@activity),
                notice: scan_notice(result)
  end

  def adapt
    @parent = @activity.adapted? ? @activity.parent_activity : @activity
    @adapted = if @activity.adapted?
                 @activity
               else
                 build_adapted_from(@parent)
               end
    @classroom = current_professor.classrooms.find(@adapted.lesson.classroom_id)
    @students = @classroom.students.order(:name)
  end

  def create
    parent = find_parent_activity
    @classroom = current_professor.classrooms.find(parent.lesson.classroom_id)
    @adapted = build_adapted_from(parent)
    assign_adapted_attributes(@adapted)

    if @adapted.save
      redirect_to grade_levels_path(
        classroom_id: @classroom.id,
        activity_id: @adapted.id,
        kind: "adapted"
      ), notice: "Atividade adaptada criada com sucesso."
    else
      @parent = parent
      @students = @classroom.students.order(:name)
      render :adapt, status: :unprocessable_entity
    end
  end

  def update
    if @activity.adapted? && params[:activity]&.key?(:student_ids)
      assign_adapted_attributes(@activity)
      saved = @activity.save
    else
      saved = @activity.update(regular_activity_params)
    end

    if saved
      redirect_to grade_levels_path(
        classroom_id: @classroom.id,
        activity_id: @activity.id,
        bimester: params[:bimester_filter].presence,
        kind: @activity.adapted? ? "adapted" : params[:kind]
      ), notice: "Atividade atualizada com sucesso."
    elsif @activity.adapted?
      @parent = @activity.parent_activity
      @adapted = @activity
      @students = @classroom.students.order(:name)
      render :adapt, status: :unprocessable_entity
    else
      redirect_to grade_levels_path(
        classroom_id: @classroom.id,
        activity_id: @activity.id,
        bimester: params[:bimester_filter].presence
      ), alert: @activity.errors.full_messages.to_sentence
    end
  end

  def destroy
    classroom_id = @classroom.id
    @activity.discard_with_generated_data!

    redirect_to grade_levels_path(
      classroom_id: classroom_id,
      bimester: params[:bimester].presence || params[:bimester_filter].presence,
      kind: params[:kind]
    ), notice: "Atividade excluída. Notas, entregas e questões ligadas a ela também foram removidas."
  end

  private

  def set_activity
    @activity = Activity
      .joins(:lesson)
      .where(
        lessons: {
          classroom_id: current_professor.classrooms.select(:id)
        }
      )
      .includes(lesson: [:classroom, :course], adapted_versions: :activity_recipients, activity_recipients: :student)
      .find(params[:id])

    @classroom = current_professor.classrooms.find(
      @activity.lesson.classroom_id
    )
  rescue ActiveRecord::RecordNotFound
    redirect_to grade_levels_path,
                alert: "Atividade não encontrada ou sem permissão de acesso."
  end

  def find_parent_activity
    Activity
      .joins(:lesson)
      .where(
        adapted: false,
        lessons: {
          classroom_id: current_professor.classrooms.select(:id)
        }
      )
      .find(params.dig(:activity, :parent_activity_id) || params[:parent_activity_id])
  end

  def build_adapted_from(parent)
    Activity.new(
      lesson: parent.lesson,
      parent_activity: parent,
      adapted: true,
      title: "#{parent.title} (adaptada)",
      activity_type: parent.activity_type,
      due_date: parent.due_date,
      maximum_score: parent.maximum_score,
      bimester: parent.bimester,
      weight: parent.weight,
      description: parent.description,
      instructions: parent.instructions,
      adaptation_kind: "reduced",
      grade_mode: "replaces"
    )
  end

  def assign_adapted_attributes(record)
    attrs = adapted_activity_params
    student_ids = Array(attrs.delete(:student_ids)).map(&:presence).compact

    record.assign_attributes(attrs)
    record.adapted = true
    record.recipient_student_ids = current_professor
                                   .students
                                   .where(id: student_ids)
                                   .pluck(:id)
  end

  def regular_activity_params
    params.require(:activity).permit(:bimester, :weight)
  end

  def adapted_activity_params
    params.require(:activity).permit(
      :title,
      :activity_type,
      :due_date,
      :maximum_score,
      :description,
      :instructions,
      :adaptation_kind,
      :grade_mode,
      :bimester,
      :weight,
      :parent_activity_id,
      student_ids: []
    )
  end

  def sheet_filename(prefix: nil)
    classroom_slug = @classroom.name.to_s.parameterize(separator: "-").presence || "turma"
    title_slug = @activity.title.to_s.parameterize(separator: "-").presence || "atividade"
    type_slug = @activity.activity_type.to_s.parameterize(separator: "-").presence || "folha"
    adapted = @activity.adapted? ? "adaptada-" : ""
    extra = prefix.to_s

    "#{extra}#{adapted}#{type_slug}-#{title_slug}-#{classroom_slug}.pdf"
  end

  def scan_notice(result)
    parts = []
    parts << "#{result.launched} #{result.launched == 1 ? 'nota lançada' : 'notas lançadas'}" if result.launched.positive?
    parts << "#{result.pending} #{result.pending == 1 ? 'cartão para conferir' : 'cartões para conferir'}" if result.pending.positive?
    parts << "#{result.skipped} já tinham nota e não foram alterados" if result.skipped.positive?
    parts.presence&.join(". ")&.+(".") || "Nenhum cartão foi lido."
  end
end
