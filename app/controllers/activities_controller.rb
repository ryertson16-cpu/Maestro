class ActivitiesController < ApplicationController
  include CorrectionHost

  before_action :authenticate_professor!
  before_action :set_activity, except: %i[create import], if: -> { action_name != "export" || params[:id].present? }

  def export
    activities = exportable_activities
    if activities.empty?
      redirect_to grade_levels_path({ classroom_id: params[:classroom_id] }.compact),
                  alert: "Não há atividade para baixar neste recorte."
      return
    end

    payload = Activities::Packager.new(activities: activities).to_pretty_json
    filename = pack_filename(activities)

    if params[:download].present?
      send_data payload,
                filename: filename,
                type: "application/json; charset=utf-8",
                disposition: "attachment"
    else
      render plain: payload, content_type: "application/json; charset=utf-8"
    end
  rescue StandardError => error
    redirect_activity_alert("Não consegui copiar o pacote desta atividade.", error)
  end

  def import
    raw = params[:pack].to_s
    upload = params[:file]
    raw = upload.read if raw.blank? && upload.respond_to?(:read)
    classroom = current_professor.classrooms.find_by(id: params[:classroom_id]) if params[:classroom_id].present?

    result = Activities::Importer.new(
      professor: current_professor,
      raw: raw,
      classroom: classroom
    ).call

    parts = []
    parts << "#{result.imported} atividade(s) recebida(s)." if result.imported.positive?
    parts << "#{result.skipped} já existiam nesta turma." if result.skipped.positive?
    parts.concat(result.errors)

    path = grade_levels_path({ classroom_id: classroom&.id }.compact)
    if result.imported.positive?
      redirect_to path, notice: parts.join(" ")
    else
      redirect_to path, alert: parts.join(" ").presence || "Nenhuma atividade recebida."
    end
  end

  def sheet
    @activity.ensure_correction_pin!
    send_exam_file(:student)
  rescue StandardError => error
    redirect_activity_alert("Não consegui gerar a folha do aluno.", error)
  end

  def key_sheet
    @activity.ensure_correction_token!
    send_exam_file(:answer_key)
  rescue StandardError => error
    redirect_activity_alert("Não consegui gerar o gabarito do professor.", error)
  end

  def exam_versions
    roster = exam_roster
    cap = Activities::ExamAssigner.maximum_versions(roster.size, @activity.activity_questions.size)
    chosen = params[:versions].to_i
    chosen = Activities::ExamAssigner::DEFAULT_SLOTS if chosen < 1
    @activity.update!(exam_version_count: chosen.clamp(1, cap))
    Activities::ExamAssigner.new(@activity).ensure!(roster)
    notice = if @activity.exam_sheets_locked?
      "As folhas já impressas continuam iguais. A nova quantidade vale para quem ainda não tem folha."
    else
      "A prova terá #{@activity.exam_version_count} versões. Cada uma troca a ordem das questões e das alternativas."
    end
    redirect_to assemble_activity_path(@activity), notice: notice
  end

  def assemble
    @activity.ensure_correction_token!
    if params[:refresh_phone_link].present? && public_site_host.blank?
      session.delete(:correction_host)
      Corrections::PhoneLink.restart!(port: request.port)
    end
    store_correction_host
    @correction_pin = @activity.ensure_correction_pin!
    @correction_url = gabarito_public_url(@activity)
    @correction_gate_url = correction_gate_public_url
    @items = @activity.activity_questions.with_attached_image.includes(:question)
    @exam_assignments = Activities::ExamAssigner.new(@activity).ensure!(exam_roster)
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
    @students = exam_roster
    @version_maximum = Activities::ExamAssigner.maximum_versions(@students.size, @items.size)
    @version_count = Activities::ExamAssigner.new(@activity).version_count(@students.size, @items.size)
    @card_readings = @activity
                    .activity_submissions
                    .with_attached_marked_photo
                    .with_attached_card_photo
                    .includes(:student)
                    .order(updated_at: :desc)
  rescue StandardError => error
    redirect_activity_alert("Não consegui abrir a prova.", error)
  end

  def open_gabarito
    @activity.ensure_correction_token!
    store_correction_host
    if public_site_host.present?
      redirect_to gabarito_path(@activity.correction_token)
      return
    end

    url = gabarito_public_url(@activity)
    if url.blank?
      redirect_to assemble_activity_path(@activity),
                  alert: "O link HTTPS do celular ainda não ficou pronto. Toque em Atualizar link."
      return
    end

    redirect_to url, allow_other_host: true
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

  def source_text
    cleaned = Questions::PromptText.sanitized(params[:source_text].to_s)
    cleaned = nil if Questions::PromptText.plain(cleaned).blank?
    @activity.update!(source_text: cleaned)
    redirect_to assemble_activity_path(@activity),
                notice: "Texto da prova salvo. Ele entra em cada folha do aluno."
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

    result = Activities::AnswerCardIntake.new(@activity, professor: current_professor).ingest!(uploads)
    redirect_to results_activity_path(@activity),
                notice: scan_notice(result)
  end

  def results
    @result = Activities::ExamResult.new(@activity)
  end

  def question_result
    @result = Activities::ExamResult.new(@activity)
    @question = @activity.activity_questions.find(params[:question_id])
    @breakdown = @result.breakdown_for(@question)
  end

  def close_correction
    corrected = 0
    missed = 0
    lesson = @activity.lesson
    classroom = lesson.classroom

    ActiveRecord::Base.transaction do
      Activities::ExamResult.new(@activity).students.each do |student|
        submission = @activity.activity_submissions.find_or_initialize_by(student: student)
        submission.professor ||= current_professor
        delivered = submission.score.present?
        if delivered
          submission.missed_exam = false
          corrected += 1
        else
          submission.professor = current_professor
          submission.missed_exam = true
          missed += 1
        end
        submission.save!
        sync_lesson_attendance!(lesson, classroom, student, delivered)
      end

      @activity.update!(correction_closed_at: Time.current)
    end

    redirect_to results_activity_path(@activity),
                notice: "#{corrected} #{corrected == 1 ? "gabarito corrigido" : "gabaritos corrigidos"}. " \
                        "#{missed} #{missed == 1 ? "ficou" : "ficaram"} sem correção e #{missed == 1 ? "passou" : "passaram"} para aluno faltou a prova. " \
                        "A chamada desta aula foi atualizada."
  end

  def edit_result
    @student = @classroom.students.find(params[:student_id])
    @submission = @activity.activity_submissions.find_by(student: @student)
    @answers = @submission&.answers.presence || {}
    @assignment = @activity.exam_assignments.find_by(student: @student)
    @presented = Activities::ExamAssigner.new(@activity).presented_for(@student)
    @score = @submission&.score
  end

  def update_result
    student = @classroom.students.find(params[:student_id])
    answers = params[:answers].presence || {}
    answers = answers.to_unsafe_h if answers.respond_to?(:to_unsafe_h)
    assignment = @activity.exam_assignments.find_by(student: student)
    score = Activities::Grader.new(@activity, assignment: assignment).score(answers)
    submission = ActivitySubmission.find_or_initialize_by(activity: @activity, student: student)
    submission.professor = current_professor
    submission.answers = answers
    submission.score = score
    submission.submitted_on ||= Date.current

    if submission.save
      redirect_to results_activity_path(@activity),
                  notice: "Acertos de #{student.name} atualizados. Nota #{format('%.1f', score).tr('.', ',')}."
    else
      redirect_to edit_result_activity_path(@activity, student_id: student),
                  alert: submission.errors.full_messages.to_sentence
    end
  end

  def clear_results
    @activity.activity_submissions.find_each { |submission| discard_submission!(submission) }
    @activity.pending_cards.find_each { |card| discard_card!(card) }
    @activity.update!(correction_closed_at: nil)
    redirect_to results_activity_path(@activity),
                notice: "Correção apagada. As notas e os cartões saíram deste resultado."
  end

  def clear_student_result
    student = @classroom.students.find(params[:student_id])
    if (submission = @activity.activity_submissions.find_by(student: student))
      discard_submission!(submission)
    end
    @activity.pending_cards.where(student: student).find_each { |card| discard_card!(card) }
    redirect_to results_activity_path(@activity),
                notice: "Correção de #{student.name} apagada."
  end

  def grades_export
    result = Activities::ExamResult.new(@activity)
    pdf = Documents::ExamGradesReport.new(
      professor: current_professor,
      activity: @activity,
      result: result
    ).render

    send_data pdf,
              filename: sheet_filename(prefix: "notas-"),
              type: "application/pdf",
              disposition: "attachment"
  end

  def adapt
    @parent = @activity.adapted? ? @activity.parent_activity : @activity
    @adapted = if @activity.adapted?
                 @activity
               else
                 build_adapted_from(@parent)
               end
    @classroom = current_professor.classrooms.find(@adapted.lesson.classroom_id)
    @students = exam_roster
  rescue StandardError => error
    redirect_activity_alert("Não consegui abrir a versão adaptada.", error)
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
  rescue ActionController::ParameterMissing
    redirect_activity_alert("Não recebi o bimestre e o peso para salvar.")
  end

  def destroy
    classroom_id = @classroom.id
    @activity.discard_with_generated_data!

    redirect_to grade_levels_path(
      classroom_id: classroom_id,
      bimester: params[:bimester].presence || params[:bimester_filter].presence,
      kind: params[:kind]
    ), notice: "Atividade excluída. Notas, entregas e questões ligadas a ela também foram removidas."
  rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed, ActiveRecord::StatementInvalid
    redirect_activity_alert("Não foi possível excluir a atividade porque ainda há registros ligados a ela.")
  end

  private

  def exam_roster
    students = @classroom.students.merge(Enrollment.where(status: "active")).distinct.order(:name)
    return students.to_a unless @activity&.adapted?

    students.where(id: @activity.recipient_student_ids).to_a
  end

  def redirect_activity_alert(message, error = nil)
    Rails.logger.error("[activities##{action_name}] #{error.class}: #{error.message}") if error
    path = if @classroom
             grade_levels_path(classroom_id: @classroom.id, activity_id: @activity&.id)
           else
             grade_levels_path
           end
    redirect_to path, alert: message
  end

  def exportable_activities
    return [ @activity ] if @activity.present?

    scope = Activity
            .joins(:lesson)
            .where(
              adapted: false,
              lessons: { professor_id: current_professor.id }
            )
            .includes(
              lesson: [ :classroom, :course, { classroom: :grade_level } ],
              activity_questions: { image_attachment: :blob },
              activity_submissions: :student,
              exam_assignments: :student,
              adapted_versions: [
                :activity_questions,
                :recipient_students,
                { activity_submissions: :student }
              ]
            )
            .order("lessons.lesson_date DESC", "activities.created_at DESC")

    if params[:classroom_id].present?
      scope = scope.where(lessons: { classroom_id: params[:classroom_id] })
    end
    if params[:bimester].present? && (1..4).cover?(params[:bimester].to_i)
      scope = scope.where(bimester: params[:bimester].to_i)
    end
    scope.to_a
  end

  def pack_filename(activities)
    if activities.size == 1
      activity = activities.first
      stamp = activity.due_date&.iso8601 || "atividade"
      slug = activity.title.to_s.parameterize.presence || "atividade"
      "atividade-#{slug}-#{stamp}.maestro.json"
    else
      "atividades-#{Date.current.iso8601}.maestro.json"
    end
  end

  def sync_lesson_attendance!(lesson, classroom, student, delivered)
    enrollment = Enrollment.find_by(professor: current_professor, student: student, classroom: classroom)
    return if enrollment.nil?

    record = AttendanceRecord.find_or_initialize_by(
      professor: current_professor,
      enrollment: enrollment,
      attendance_date: lesson.lesson_date,
      lesson: lesson
    )
    record.status = delivered ? "present" : "absent"
    record.save!
  end

  def discard_submission!(submission)
    detach_attachment(submission.card_photo)
    detach_attachment(submission.marked_photo)
    submission.destroy!
  rescue StandardError
    submission.delete
  end

  def discard_card!(card)
    detach_attachment(card.card)
    card.destroy!
  rescue StandardError
    card.delete
  end

  def detach_attachment(attachment)
    return unless attachment&.attached?

    attachment.purge
  rescue StandardError
    attachment.detach
  end

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
      source_text: parent.source_text,
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

  def send_exam_file(mode)
    students = exam_roster
    Activities::ExamAssigner.new(@activity).ensure!(students)
    if mode == :student
      question_count = @activity.activity_questions.to_a.count(&:objective?)
      @activity.lock_printed_sheets!(question_count)
    end
    docx = params[:file].to_s == "docx"
    options = {
      professor: current_professor,
      activity: @activity,
      mode: mode
    }
    if mode == :student
      options[:correction_url] = gabarito_public_url(@activity)
      options[:students] = students
      options[:student_url] = ->(student) { gabarito_student_url(@activity, student) }
      options[:columns] = params[:columns].to_i == 2 ? 2 : 1
    end
    data = if docx
             Documents::ActivityDocx.new(**options).render
           else
             Documents::ActivitySheet.new(**options).render
           end
    send_data data,
              filename: sheet_filename(prefix: mode == :answer_key ? "gabarito-" : nil, extension: docx ? "docx" : "pdf"),
              type: docx ? "application/vnd.openxmlformats-officedocument.wordprocessingml.document" : "application/pdf",
              disposition: "attachment"
  end

  def sheet_filename(prefix: nil, extension: "pdf")
    classroom_slug = @classroom.name.to_s.parameterize(separator: "-").presence || "turma"
    title_slug = @activity.title.to_s.parameterize(separator: "-").presence || "atividade"
    type_slug = @activity.activity_type.to_s.parameterize(separator: "-").presence || "folha"
    adapted = @activity.adapted? ? "adaptada-" : ""
    extra = prefix.to_s

    "#{extra}#{adapted}#{type_slug}-#{title_slug}-#{classroom_slug}.#{extension}"
  end

  def scan_notice(result)
    parts = []
    parts << "#{result.launched} #{result.launched == 1 ? 'nota lançada' : 'notas lançadas'}" if result.launched.positive?
    parts << "#{result.pending} #{result.pending == 1 ? 'cartão para conferir' : 'cartões para conferir'}" if result.pending.positive?
    parts << "#{result.skipped} já tinham nota e não foram alterados" if result.skipped.positive?
    parts.presence&.join(". ")&.+(".") || "Nenhum cartão foi lido."
  end
end
