require "pdf/reader"

class MonitoringController < ApplicationController
  before_action :authenticate_professor!
  before_action :load_report
  before_action :require_selected_classroom, only: :email_digest
  skip_before_action :load_report, only: :activity_result

  def index
  end

  def activity_result
    classroom = current_professor.classrooms.find(params[:classroom_id])

    activity = Activity
              .joins(:lesson)
              .where(
                lessons: {
                  professor_id: current_professor.id,
                  classroom_id: classroom.id
                }
              )
              .includes(:lesson)
              .find(params[:activity_id])

    student = classroom.students.find(params[:student_id])

    submission = ActivitySubmission.find_by(
      professor: current_professor,
      activity: activity,
      student: student
    )

    minimum_score =
      classroom.bimester_settings
              .find_by(bimester: activity.bimester)
              &.minimum_score || 6.0

    letterhead = Documents::Letterhead.new(current_professor)
    pdf = Prawn::Document.new(
      page_size: "A4",
      page_layout: :portrait,
      margin: 48
    )

    letterhead.draw(
      pdf,
      title: "RESULTADO DA ATIVIDADE",
      subtitle: "#{student.name} · #{classroom.name}"
    )

    pdf.fill_color "333333"
    pdf.text "Atividade: #{activity.title}", size: 12
    pdf.text "Data: #{I18n.l(activity.lesson.lesson_date, format: :long)}", size: 12

    pdf.move_down 20
    pdf.fill_color "000000"

    if NumericScore.recorded?(submission&.score)
      score = submission.score.to_f
      score_text = format_score(score)
      minimum_text = format_score(minimum_score)

      result_text =
        if score >= minimum_score.to_f
          "Atingiu o mínimo esperado para esta atividade."
        else
          "Ficou abaixo do mínimo esperado para esta atividade."
        end

      pdf.text "Nota: #{score_text}", size: 14, style: :bold
      pdf.text "Nota mínima: #{minimum_text}", size: 12
      pdf.move_down 8
      pdf.text result_text, size: 12
    else
      pdf.text "Nota: ainda não registrada", size: 14, style: :bold
      pdf.text "A nota mínima para esta atividade é #{format_score(minimum_score)}.",
             size: 12
    end

    pdf.move_down 30
    pdf.fill_color "666666"
    pdf.text "Resultado preparado pelo sistema para revisão do professor.",
            size: 9

    send_data pdf.render,
              filename: "resultado-#{student.name.parameterize}.pdf",
              type: "application/pdf",
              disposition: "attachment"
  rescue ActiveRecord::RecordNotFound
    redirect_to monitoring_path,
                alert: "Não foi possível localizar a turma, atividade ou aluno."
  ensure
    letterhead&.cleanup
  end

  def email_digest
    alerts = @report.student_rows.select(&:alerted?)

    if alerts.empty?
      redirect_to monitoring_path(monitoring_redirect_params),
                  alert: "Não há alertas para enviar nesta turma e neste mês."
      return
    end

    MonitoringMailer.digest(
      professor: current_professor,
      classroom: @selected_classroom,
      month: @monitoring_month,
      alerts: alerts
    ).deliver_now

    redirect_to monitoring_path(monitoring_redirect_params),
                notice: "Resumo enviado para #{current_professor.email}."
  end

  def import_results
    load_import_context!

    upload = params[:results_pdf]

    unless upload.respond_to?(:tempfile)
      return import_fail("Selecione um arquivo PDF.")
    end

    if upload.size > 10.megabytes
      return import_fail("O PDF deve ter no máximo 10 MB.")
    end

    signature = upload.tempfile.read(5)
    upload.tempfile.rewind

    unless signature == "%PDF-"
      return import_fail("O arquivo selecionado não parece ser um PDF válido.")
    end

    pdf_text = PDF::Reader.new(upload.tempfile.path)
                        .pages
                        .map(&:text)
                        .join("\n")

    @import_rows = build_import_preview_rows(parse_pdf_result_rows(pdf_text))

    if @import_rows.empty?
      return import_fail(
        "Não encontrei linhas de alunos e notas no PDF. Verifique se o formato é compatível."
      )
    end

    render "monitoring/import_results"
  rescue ActiveRecord::RecordNotFound
    redirect_to monitoring_path,
                alert: "Não foi possível localizar a turma ou atividade selecionada."
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::EncryptedPDFError
    import_fail(
      "Não foi possível ler o PDF. Verifique se o arquivo não está corrompido ou protegido."
    )
  end

  def confirm_results
    load_import_context!

    raw_results = params[:results]

    unless raw_results.respond_to?(:values)
      return redirect_to monitoring_path(
        classroom_id: @import_classroom.id,
        activity_id: @import_activity.id
      ), alert: "Não recebi resultados para importar."
    end

    prepared_rows = []
    seen_student_ids = []

    raw_results.values.each do |raw_row|
      row = raw_row.permit(:student_id, :score)
      score_text = row[:score].to_s.strip

      # Campo vazio não substitui nem apaga uma nota que já exista.
      next if score_text.blank?

      student = @import_classroom.students.find_by(id: row[:student_id])

      unless student
        return redirect_to monitoring_path(
          classroom_id: @import_classroom.id,
          activity_id: @import_activity.id
        ), alert: "Selecione um aluno válido da turma para cada nota."
      end

      if seen_student_ids.include?(student.id)
        return redirect_to monitoring_path(
          classroom_id: @import_classroom.id,
          activity_id: @import_activity.id
        ), alert: "O mesmo aluno foi selecionado mais de uma vez."
      end

      score = Float(score_text.tr(",", ".")) rescue nil

      unless score&.finite? && score.between?(0, 10)
        return redirect_to monitoring_path(
          classroom_id: @import_classroom.id,
          activity_id: @import_activity.id
        ), alert: "Todas as notas precisam estar entre 0 e 10."
      end

      seen_student_ids << student.id
      prepared_rows << [student, score]
    end

    if prepared_rows.empty?
      return redirect_to monitoring_path(
        classroom_id: @import_classroom.id,
        activity_id: @import_activity.id
      ), alert: "Não há notas numéricas para salvar."
    end

    ActivitySubmission.transaction do
      prepared_rows.each do |student, score|
        submission = ActivitySubmission.find_or_initialize_by(
          activity: @import_activity,
          student: student
        )

        submission.professor = current_professor
        submission.score = score
        submission.save!
      end
    end

    redirect_to monitoring_path(
      classroom_id: @import_classroom.id,
      activity_id: @import_activity.id
    ), notice: "Notas importadas. Confira os resultados no monitoramento."
  rescue ActiveRecord::RecordNotFound
    redirect_to monitoring_path,
                alert: "Não foi possível localizar a turma ou atividade selecionada."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to monitoring_path(
      classroom_id: @import_classroom&.id,
      activity_id: @import_activity&.id
    ), alert: "Não foi possível salvar uma das notas: #{error.record.errors.full_messages.to_sentence}"
  rescue ActiveRecord::RecordNotUnique
    redirect_to monitoring_path(
      classroom_id: @import_classroom&.id,
      activity_id: @import_activity&.id
    ), alert: "Um dos resultados já foi atualizado. Confira as notas e tente novamente."
  end

  private

  def load_import_context!
    @import_classroom = current_professor.classrooms.find(params[:classroom_id])

    @import_activity =
      Activity
        .joins(:lesson)
        .where(
          lessons: {
            professor_id: current_professor.id,
            classroom_id: @import_classroom.id
          }
        )
        .find(params[:activity_id])

    @import_students = @import_classroom.students.order(:name).to_a

    @existing_submissions =
      ActivitySubmission
        .where(
          activity: @import_activity,
          student_id: @import_students.map(&:id)
        )
        .index_by(&:student_id)
  end

  def parse_pdf_result_rows(pdf_text)
    rows = []

    pdf_text.each_line do |line|
      match = line.match(
        /\A\s*(?<name>.+?)\s{2,}(?<score>—|–|-|\d+(?:[,.]\d+)?)\s{2,}(?<result>.+?)\s*\z/
      )

      next unless match

      score_text = match[:score].strip
      no_score = score_text.match?(/\A[—–-]\z/)

      rows << {
        name: match[:name].strip,
        score: no_score ? nil : score_text.tr(",", ".")
      }
    end

    rows
  end

  def build_import_preview_rows(parsed_rows)
    parsed_rows.map do |row|
      matching_students =
        @import_students.select do |student|
          normalize_import_name(student.name) == normalize_import_name(row[:name])
        end

      student = matching_students.one? ? matching_students.first : nil
      existing = student ? @existing_submissions[student.id] : nil

      match_label =
        if matching_students.one?
          "Correspondência única pelo nome"
        elsif matching_students.empty?
          "Aluno não localizado: escolha manualmente"
        else
          "Nome repetido na turma: escolha o aluno correto"
        end

      {
        name: row[:name],
        score: row[:score],
        student_id: student&.id,
        match_label: match_label,
        existing_score: existing&.score
      }
    end
  end

  def normalize_import_name(value)
    value.to_s
        .unicode_normalize(:nfkd)
        .gsub(/\p{Mn}/, "")
        .downcase
        .gsub(/[^a-z0-9]+/, " ")
        .strip
  end

  def load_report
    @classrooms = current_professor
                  .classrooms
                  .includes(:grade_level)
                  .order(:name)

    @classroom_student_counts = Enrollment
                                .where(professor: current_professor, status: "active")
                                .group(:classroom_id)
                                .count

    @monitoring_month = selected_month
    @alert_filter = params[:filter].presence || "all"

    @selected_classroom =
      if params[:classroom_id].present?
        current_professor.classrooms.find_by(id: params[:classroom_id])
      else
        remembered_classroom
      end
    remember_current_classroom(@selected_classroom)
    
    @activities =
      if @selected_classroom.present?
        Activity
          .joins(:lesson)
          .where(
            lessons: {
            professor_id: current_professor.id,
            classroom_id: @selected_classroom.id
          }
        )
        .includes(:lesson)
        .order("lessons.lesson_date DESC")
    else
      Activity.none
    end

  @selected_activity =
    @activities.find_by(id: params[:activity_id])

  @activity_submissions_by_student = {}
  @minimum_score = 6.0

  if @selected_activity.present?
    submissions = ActivitySubmission.where(
      activity: @selected_activity,
      student_id: @selected_classroom.students.select(:id)
    )

    @activity_submissions_by_student =
      submissions.index_by(&:student_id)

    @minimum_score =
      @selected_classroom
        .bimester_settings
        .find_by(bimester: @selected_activity.bimester)
        &.minimum_score || 6.0
  end

    @report = Monitoring::AlertReport.new(
      professor: current_professor,
      classroom: @selected_classroom,
      month: @monitoring_month,
      filter: @alert_filter
    )

    @classroom_alert_counts = @report.classroom_alert_counts
    @student_rows = @report.student_rows
    @visible_rows = @report.visible_rows
    @alert_summary = @report.summary
    @has_alerts = @report.has_alerts?
    @overdue_projects = Project.overdue_for(current_professor)
  end

  def import_fail(message)
    @import_error = message
    flash.now[:alert] = message
    render "monitoring/import_results", status: :unprocessable_entity
  end

  def format_score(value)
    format("%.1f", value.to_f).tr(".", ",")
  end

  def require_selected_classroom
    return if @selected_classroom.present?

    redirect_to monitoring_path, alert: "Selecione uma turma para enviar o resumo."
  end

  def selected_month
    return Date.current.beginning_of_month if params[:month].blank?

    Date.strptime("#{params[:month]}-01", "%Y-%m-%d").beginning_of_month
  rescue Date::Error
    Date.current.beginning_of_month
  end

  def monitoring_redirect_params
    {
      classroom_id: @selected_classroom&.id,
      month: @monitoring_month.strftime("%Y-%m"),
      filter: @alert_filter
    }.compact
  end
end
