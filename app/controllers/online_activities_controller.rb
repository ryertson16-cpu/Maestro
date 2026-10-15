class OnlineActivitiesController < ApplicationController
  before_action :authenticate_professor!

  def new
    @classrooms = current_professor.classrooms.order(:name)
    @courses = current_professor.courses.active.order(:name)
  end

  def preview
    upload = params[:spreadsheet]
    unless upload.respond_to?(:tempfile)
      return fail_new("Selecione a planilha de respostas do formulário.")
    end
    if upload.size > 10.megabytes
      return fail_new("A planilha deve ter no máximo 10 MB.")
    end

    filename = upload.original_filename.to_s
    unless filename.downcase.match?(/\.(xlsx|csv)\z/)
      return fail_new("Envie um arquivo .xlsx ou .csv do Google Forms.")
    end

    rows = Activities::OnlineFormParser.parse(
      path: upload.tempfile.path,
      filename: filename
    )
    if rows.empty?
      return fail_new("Não encontrei nome, turma e pontuação nessa planilha.")
    end

    title = params[:title].presence
    lesson_date = params[:lesson_date].presence
    preview = Activities::OnlineFormPreview.new(
      professor: current_professor,
      rows: rows,
      title: title,
      lesson_date: lesson_date
    )
    @title = title || preview.suggested_title
    @lesson_date = lesson_date || preview.suggested_date
    if title.blank? || lesson_date.blank?
      preview = Activities::OnlineFormPreview.new(
        professor: current_professor,
        rows: rows,
        title: @title,
        lesson_date: @lesson_date
      )
    end
    @items = preview.items
    @course_id = params[:course_id]
    @classrooms = current_professor.classrooms.order(:name)
    @courses = current_professor.courses.active.order(:name)
    @max_raw_score = preview.max_raw_score

    session[:online_form_import] = {
      "title" => @title,
      "max_raw_score" => @max_raw_score
    }

    render :preview
  rescue StandardError => error
    Rails.logger.warn("[online-form] #{error.class}: #{error.message}")
    fail_new("Não foi possível ler a planilha. Use o export de respostas do Google Forms.")
  end

  def create
    items = import_item_params.filter_map { |item| prepared_item(item) }
    if items.empty?
      redirect_to new_online_activity_path,
                  alert: "Não foi possível lançar a atividade online. Marque pelo menos um aluno com turma e ficha válidas."
      return
    end

    title = params[:title].presence || "Questionário online"
    lesson_date = Date.parse(params[:lesson_date].to_s)

    created = Activities::OnlineFormImporter.new(professor: current_professor).import!(
      title: title,
      lesson_date: lesson_date,
      course_id: params[:course_id],
      items: items
    )

    session.delete(:online_form_import)
    first = created.find { |item| item[:activity].present? }
    unless first
      redirect_to new_online_activity_path,
                  alert: "Não foi possível lançar a atividade online. Nenhum aluno novo para incluir."
      return
    end

    remember_current_classroom(first[:classroom])
    redirect_to activity_destination(first), flash: import_flash(created, first)
  rescue Date::Error
    redirect_to new_online_activity_path, alert: "Não foi possível lançar a atividade online. Informe a data da aula."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to new_online_activity_path,
                alert: "Não foi possível lançar a atividade online. #{error.record.errors.full_messages.to_sentence}"
  rescue StandardError => error
    Rails.logger.warn("[online-form] #{error.class}: #{error.message}")
    redirect_to new_online_activity_path,
                alert: "Não foi possível lançar a atividade online. Tente de novo com a planilha do Google Forms."
  end

  private

  def fail_new(message)
    @classrooms = current_professor.classrooms.order(:name)
    @courses = current_professor.courses.active.order(:name)
    flash.now[:alert] = message
    render :new, status: :unprocessable_entity
  end

  def import_item_params
    raw = params[:items]
    if raw.is_a?(Array)
      raw
    elsif raw.respond_to?(:to_unsafe_h)
      raw.to_unsafe_h.values
    else
      []
    end
  end

  def prepared_item(raw)
    row = if raw.respond_to?(:permit)
            raw.permit(:include, :classroom_id, :student_id, :score, :submitted_at, :name)
          else
            raw.to_h.symbolize_keys
          end
    return unless ActiveModel::Type::Boolean.new.cast(row[:include])
    return if row[:classroom_id].blank? || row[:student_id].blank?

    classroom = current_professor.classrooms.find(row[:classroom_id])
    student = classroom.students.find(row[:student_id])
    score = row[:score].presence && Float(row[:score].to_s.tr(",", "."))
    raise ArgumentError if score && !(score.finite? && score.between?(0, 10))

    {
      classroom_id: classroom.id,
      student_id: student.id,
      score: score,
      submitted_at: row[:submitted_at].presence,
      name: row[:name]
    }
  rescue ArgumentError
    nil
  end

  def activity_destination(result)
    activity = result[:activity]
    grade_levels_path(
      classroom_id: result[:classroom].id,
      activity_id: activity.id,
      bimester: activity.bimester,
      kind: activity.adapted? ? "adapted" : "regular"
    )
  end

  def import_flash(created, result)
    added = created.sum { |item| item[:count].to_i }
    skipped = created.sum { |item| item[:skipped].to_i }

    if added.positive?
      payload = {
        maestro_recap: Maestro::ActionRecap.new(current_professor).grades(
          result[:activity],
          classroom: result[:classroom]
        )
      }
      if skipped.positive?
        payload[:warning] = "#{skipped} aluno(s) já tinham nota nesta atividade e não foram alterados."
      end
      return payload
    end

    {
      warning: "A atividade já existia. Nenhum aluno novo recebeu nota: todos já tinham lançamento."
    }
  end
end
