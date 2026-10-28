class TimetablesController < ApplicationController
  before_action :authenticate_professor!

  def show
    load_week
    load_entries
  end

  def create
    result = Lessons::WeeklyTimetableImporter.new(
      professor: current_professor,
      upload: params[:timetable]
    ).call

    if result[:ok]
      redirect_to timetable_path, notice: result[:message]
    else
      redirect_to timetable_path, alert: result[:error]
    end
  end

  def generate_week
    load_week
    classrooms = target_classrooms

    if current_professor.timetable_entries.none?
      redirect_to timetable_path(week: @week_start),
                  alert: "Gere a grade pelo PDF antes de criar as aulas."
      return
    end

    if classroom_scope? && classrooms.empty?
      redirect_to timetable_path(week: @week_start, scope: "classroom"),
                  alert: "Escolha a turma para gerar só o horário dela."
      return
    end

    if classrooms.empty?
      redirect_to timetable_path(week: @week_start),
                  alert: "Nenhuma turma da grade está cadastrada no Maestro."
      return
    end

    created = 0
    skipped = 0
    attendances = 0
    classrooms.each do |classroom|
      result = SchoolCalendar::LessonFactory.new(
        professor: current_professor,
        classroom: classroom,
        starts_on: @week_start,
        ends_on: @week_start + 4
      ).call
      created += result[:created].to_i
      skipped += result[:skipped].to_i
      attendances += result[:attendances].to_i
    end

    week_label = "#{I18n.l(@week_start)} a #{I18n.l(@week_start + 4)}"
    scope_label = classrooms.one? ? classrooms.first.name : "todas as turmas da grade"
    parts = ["Criei #{created} aula(s) em #{scope_label} (#{week_label})."]
    parts << "#{skipped} já existiam." if skipped.positive?
    parts << "Frequência gerada em #{attendances} tempo(s)." if attendances.positive?
    redirect_to timetable_path(timetable_filter_params), notice: parts.join(" ")
  end

  def generate_day
    lesson_date = Date.parse(params[:lesson_date].to_s)
    result = Lessons::DayLessonsFromTimetable.new(
      professor: current_professor,
      lesson_date: lesson_date,
      upload: params[:timetable],
      classroom: classroom_scope? ? current_professor.classrooms.find_by(id: params[:classroom_id]) : nil
    ).call

    if result[:ok]
      redirect_to timetable_path(week: lesson_date, scope: params[:scope], classroom_id: params[:classroom_id]),
                  notice: result[:message]
    else
      redirect_to timetable_path(week: lesson_date, scope: params[:scope], classroom_id: params[:classroom_id]),
                  alert: result[:error]
    end
  rescue Date::Error
    redirect_to timetable_path, alert: "Data inválida."
  end

  def slots
    date = Date.parse(params[:date].to_s)
    entries = current_professor.timetable_entries
                               .includes(:classroom, :course)
                               .where(weekday: date.cwday)
                               .order(:period)
    if params[:classroom_id].present?
      entries = entries.where(classroom_id: params[:classroom_id])
    end

    render json: {
      ok: true,
      weekday: TimetableEntry::WEEKDAY_LABELS[date.cwday],
      slots: entries.map { |entry| slot_json(entry, date) }
    }
  rescue Date::Error
    render json: { ok: false, error: "Data inválida." }, status: :unprocessable_entity
  end

  private

  def load_week
    @anchor = parse_week_date
    @week_start = @anchor - (@anchor.cwday - 1)
    @week_dates = (1..5).index_with { |weekday| @week_start + (weekday - 1) }
  end

  def load_entries
    @all_entries = current_professor.timetable_entries.includes(:classroom, :course).order(:weekday, :period)
    @timetable_classrooms = @all_entries.map(&:classroom).uniq.sort_by(&:name)
    @classroom = resolve_classroom
    @scope = classroom_scope? ? "classroom" : "all"
    @entries = if classroom_scope? && @classroom
                 @all_entries.select { |entry| entry.classroom_id == @classroom.id }
               elsif classroom_scope?
                 []
               else
                 @all_entries
               end
    @grid = @entries.group_by { |entry| [entry.weekday, entry.period] }
    @periods = (1..9).to_a
    @weekdays = (1..5).to_a
  end

  def resolve_classroom
    return unless classroom_scope?

    current_professor.classrooms.find_by(id: params[:classroom_id])
  end

  def classroom_scope?
    params[:scope].to_s == "classroom"
  end

  def target_classrooms
    ids = current_professor.timetable_entries.distinct.pluck(:classroom_id)
    relation = current_professor.classrooms.where(id: ids)
    return relation.where(id: params[:classroom_id]).to_a if classroom_scope?

    relation.order(:name).to_a
  end

  def timetable_filter_params
    filter = { week: @week_start }
    if classroom_scope?
      filter[:scope] = "classroom"
      filter[:classroom_id] = params[:classroom_id]
    end
    filter
  end

  def parse_week_date
    Date.parse(params[:week].presence || Date.current.to_s)
  rescue Date::Error
    Date.current
  end

  def slot_json(entry, date)
    clock = Lessons::WeeklyTimetableImporter::PERIOD_CLOCK[entry.period] || []
    {
      id: entry.id,
      classroom_id: entry.classroom_id,
      classroom_name: entry.classroom.name,
      course_id: entry.course_id,
      course_name: entry.course&.name,
      period: entry.period,
      siage_time_slot: entry.time_slot_label,
      time_range: clock.join(" – "),
      new_lesson_url: new_lesson_path(
        classroom_id: entry.classroom_id,
        lesson_date: date,
        period: entry.period
      )
    }
  end
end
