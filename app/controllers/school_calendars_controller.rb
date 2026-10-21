class SchoolCalendarsController < ApplicationController
  before_action :authenticate_professor!

  def show
    @year = (params[:year].presence || Date.current.year).to_i
    @classrooms = current_professor.classrooms.order(:name)
    @classroom = resolve_classroom(fallback: true)
    @days = current_professor.school_calendar_days.where(day: Date.new(@year, 1, 1)..Date.new(@year, 12, 31)).order(:day)
    @entries = if @classroom
                 current_professor.timetable_entries.where(classroom: @classroom).includes(:course).order(:weekday, :period)
               else
                 []
               end
    @courses = current_professor.courses.active.order(:name)
    @year_view = SchoolCalendar::YearView.new(year: @year, marked_days: @days)
    @selected_day = parse_selected_day
    @selected_slots = selected_slots_for(@selected_day)
    @tempos_by_weekday = tempos_by_weekday
  end

  def create_day
    day = current_professor.school_calendar_days.find_or_initialize_by(day: params[:day])
    day.kind = params[:kind]
    day.name = params[:name]

    if day.save
      redirect_to school_calendar_path(year: day.day.year, classroom_id: params[:classroom_id], day: day.day),
                  notice: "Dia letivo atualizado."
    else
      redirect_to school_calendar_path(classroom_id: params[:classroom_id]),
                  alert: day.errors.full_messages.to_sentence
    end
  end

  def apply_holidays
    year = (params[:year].presence || Date.current.year).to_i
    SchoolCalendar::Holidays.for_year(year).each do |date, name|
      day = current_professor.school_calendar_days.find_or_initialize_by(day: date)
      day.kind = "holiday"
      day.name = name
      day.save!
    end

    SchoolCalendar::YearTemplate.apply(current_professor, year)

    redirect_to school_calendar_path(year: year, classroom_id: params[:classroom_id]),
                notice: "Calendário de #{year} aplicado. Clique num dia para ajustar feriado, recesso ou planejamento."
  end

  def generate_lessons
    classroom = current_professor.classrooms.find(params[:classroom_id])
    starts_on = Date.parse(params[:starts_on].presence || params[:lesson_date].to_s)
    ends_on = Date.parse(params[:ends_on].presence || params[:lesson_date].to_s)

    unless SchoolCalendar::LessonPrompt.school_day?(current_professor, starts_on)
      redirect_to school_calendar_path(year: starts_on.year, classroom_id: classroom.id, day: starts_on),
                  alert: "Este dia não é letivo."
      return
    end

    ensure_grade_slot!(classroom, starts_on)

    if current_professor.timetable_entries.where(classroom: classroom, weekday: starts_on.cwday).none?
      redirect_to school_calendar_path(year: starts_on.year, classroom_id: classroom.id, day: starts_on),
                  alert: "Informe o tempo da aula no campo Tempo."
      return
    end

    result = SchoolCalendar::LessonFactory.new(
      professor: current_professor,
      classroom: classroom,
      starts_on: starts_on,
      ends_on: ends_on
    ).call

    redirect_to school_calendar_path(year: starts_on.year, classroom_id: classroom.id, day: starts_on),
                notice: generate_notice(starts_on, result)
  rescue Date::Error
    redirect_to school_calendar_path(classroom_id: params[:classroom_id]),
                alert: "Escolha um dia no calendário para gerar a aula."
  rescue ActiveRecord::RecordNotFound
    redirect_to school_calendar_path, alert: "Turma não encontrada."
  end

  def create_lesson_from_timetable
    classroom = current_professor.classrooms.find(params[:classroom_id])
    lesson_date = Date.parse(params[:lesson_date].to_s)

    unless SchoolCalendar::LessonPrompt.school_day?(current_professor, lesson_date)
      render json: { ok: false, error: "Este dia não é letivo." }, status: :unprocessable_entity
      return
    end

    result = Lessons::TimetableLessonGenerator.new(
      professor: current_professor,
      classroom: classroom,
      lesson_date: lesson_date,
      upload: params[:timetable],
      course: current_professor.courses.find_by(id: params[:course_id])
    ).call

    unless result[:ok]
      render json: { ok: false, error: result[:error] }, status: :unprocessable_entity
      return
    end

    persist_timetable_slots!(classroom, lesson_date, result)
    lessons = build_lessons_from_timetable(classroom, lesson_date, result)
    attendances = lessons.sum do |lesson|
      SchoolCalendar::AttendanceSeeder.new(
        professor: current_professor,
        classroom: classroom,
        lesson: lesson
      ).call
    end
    bimester = SchoolCalendar::LessonPrompt.bimester_label(lesson_date)
    tempos = lessons.map(&:siage_time_slot).compact.uniq.join(" e ")

    render json: {
      ok: true,
      message: [
        result[:message],
        bimester && "A aula entra no #{bimester}.",
        tempos.present? && "Frequência criada para #{tempos}.",
        attendances.positive? && "#{attendances} registro(s) de chamada."
      ].select { |part| part.present? }.join(" "),
      warning: result[:warning],
      lesson_id: lessons.last&.id,
      diary_url: attendance_records_path(
        classroom_id: classroom.id,
        attendance_date: lesson_date
      )
    }
  rescue ActiveRecord::RecordInvalid => error
    render json: { ok: false, error: error.record.errors.full_messages.to_sentence },
           status: :unprocessable_entity
  rescue ActiveRecord::RecordNotFound
    render json: { ok: false, error: "Turma não encontrada." }, status: :not_found
  rescue Date::Error
    render json: { ok: false, error: "Escolha o dia da aula no calendário." },
           status: :unprocessable_entity
  end

  def create_entry
    classroom = current_professor.classrooms.find(params[:classroom_id])
    entry = current_professor.timetable_entries.find_or_initialize_by(
      classroom: classroom,
      weekday: params[:weekday].to_i,
      period: params[:period].to_i
    )
    entry.course_id = params[:course_id]
    entry.time_slot = "#{params[:period].to_i}º tempo"

    if entry.save
      redirect_to school_calendar_path(year: params[:year], classroom_id: classroom.id, day: params[:day]),
                  notice: "Horário salvo."
    else
      redirect_to school_calendar_path(year: params[:year], classroom_id: classroom.id, day: params[:day]),
                  alert: entry.errors.full_messages.to_sentence
    end
  end

  def destroy_entry
    entry = current_professor.timetable_entries.find(params[:id])
    classroom_id = entry.classroom_id
    entry.destroy
    redirect_to school_calendar_path(year: params[:year], classroom_id: classroom_id, day: params[:day]),
                notice: "Horário removido."
  end

  def destroy_day
    day = current_professor.school_calendar_days.find(params[:id])
    year = day.day.year
    day.destroy
    redirect_to school_calendar_path(year: year, classroom_id: params[:classroom_id]),
                notice: "Dia removido do calendário."
  end

  private

  def parse_selected_day
    raw = params[:day].presence || params[:lesson_date].presence
    date = raw.present? ? Date.parse(raw.to_s) : Date.current
    return date if date.year == @year

    last = Date.new(@year, date.month, 1).end_of_month.day
    Date.new(@year, date.month, [date.day, last].min)
  rescue Date::Error, ArgumentError
    Date.new(@year, 1, 1)
  end

  def generate_notice(day, result)
    bimester = SchoolCalendar::LessonPrompt.bimester_label(day)
    parts = ["Criei #{result[:created]} aula(s) neste dia"]
    parts << "no #{bimester}" if bimester
    parts << "e a frequência de cada tempo" if result[:attendances].to_i.positive? || result[:created].positive?
    sentence = "#{parts.join(" ")}."
    sentence += " #{result[:skipped]} já existiam." if result[:skipped].to_i.positive?
    sentence
  end

  def selected_slots_for(date)
    return [] unless @classroom

    current_professor.timetable_entries
                     .where(classroom: @classroom, weekday: date.cwday)
                     .order(:period)
                     .map(&:time_slot_label)
  end

  def tempos_by_weekday
    return {} unless @classroom

    current_professor.timetable_entries
                     .where(classroom: @classroom)
                     .order(:weekday, :period)
                     .group_by(&:weekday)
                     .transform_values { |rows| rows.map(&:time_slot_label) }
  end

  def ensure_grade_slot!(classroom, date)
    weekday = date.cwday
    return unless (1..6).cover?(weekday)
    return if current_professor.timetable_entries.where(classroom: classroom, weekday: weekday).exists?

    period = params[:period].to_i
    return unless period.positive?

    entry = current_professor.timetable_entries.find_or_initialize_by(
      classroom: classroom,
      weekday: weekday,
      period: period
    )
    entry.course_id = params[:course_id].presence
    entry.time_slot = "#{period}º tempo"
    entry.save!
  end

  def persist_timetable_slots!(classroom, lesson_date, result)
    weekday = result[:weekday].to_i
    return unless (1..6).cover?(weekday)

    Array(result[:slots]).each do |slot|
      period = slot[:period].to_i
      next unless period.positive?

      entry = current_professor.timetable_entries.find_or_initialize_by(
        classroom: classroom,
        weekday: weekday,
        period: period
      )
      entry.course_id = result[:course_id]
      entry.time_slot = slot[:time_slot].presence || "#{period}º tempo"
      entry.save
    end
  end

  def build_lessons_from_timetable(classroom, lesson_date, result)
    slots = Array(result[:slots])
    if slots.empty?
      slots = [{ time_slot: result[:siage_time_slot].presence || "1º tempo" }]
    end

    slots.map do |slot|
      time_slot = slot[:time_slot].presence || "#{slot[:period].to_i}º tempo"
      lesson = current_professor.lessons.find_or_initialize_by(
        classroom: classroom,
        lesson_date: lesson_date,
        course_id: result[:course_id],
        siage_time_slot: time_slot
      )
      lesson.assign_attributes(
        theme: result[:theme],
        objective: result[:objective],
        content: result[:content],
        methodology: result[:methodology],
        siage_period: result[:siage_period],
        siage_class_mode: result[:siage_class_mode],
        siage_class_type: result[:siage_class_type],
        siage_time_slot: time_slot
      )
      lesson.save!
      lesson
    end
  end
end
