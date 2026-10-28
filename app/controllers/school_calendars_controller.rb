class SchoolCalendarsController < ApplicationController
  before_action :authenticate_professor!

  def show
    @year = (params[:year].presence || Date.current.year).to_i
    @classrooms = current_professor.classrooms.order(:name)
    @classroom = current_professor.classrooms.find_by(id: params[:classroom_id]) if params[:classroom_id].present?
    @days = current_professor.school_calendar_days.where(day: Date.new(@year, 1, 1)..Date.new(@year, 12, 31)).order(:day)
    @entries = if @classroom
                 current_professor.timetable_entries.where(classroom: @classroom).includes(:course).order(:weekday, :period)
               else
                 []
               end
    @courses = current_professor.courses.active.order(:name)
    @year_view = SchoolCalendar::YearView.new(year: @year, marked_days: @days)
    @selected_day = parse_selected_day
    @day_entries = day_entries_for(@selected_day)
    @selected_slots = @day_entries.map { |entry| "#{entry.period}º · #{entry.classroom.name}" }
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
    lesson_date = Date.parse(params[:starts_on].presence || params[:lesson_date].to_s)
    calendar_location = { year: lesson_date.year, classroom_id: params[:classroom_id], day: lesson_date }

    unless SchoolCalendar::LessonPrompt.school_day?(current_professor, lesson_date)
      redirect_to school_calendar_path(calendar_location), alert: "Este dia não é letivo."
      return
    end

    only_one = ActiveModel::Type::Boolean.new.cast(params[:only_classroom])
    classroom = current_professor.classrooms.find_by(id: params[:classroom_id]) if only_one
    if only_one
      ensure_grade_slot!(classroom, lesson_date) if classroom
      unless classroom
        redirect_to school_calendar_path(calendar_location), alert: "Escolha a turma para gerar só a grade dela."
        return
      end
    end

    result = Lessons::DayLessonsFromTimetable.new(
      professor: current_professor,
      lesson_date: lesson_date,
      classroom: classroom
    ).call

    if result[:ok]
      redirect_to school_calendar_path(calendar_location), notice: result[:message]
    else
      redirect_to school_calendar_path(calendar_location), alert: result[:error]
    end
  rescue Date::Error
    redirect_to school_calendar_path(classroom_id: params[:classroom_id]),
                alert: "Escolha um dia no calendário para gerar a aula."
  end

  def create_lesson_from_timetable
    lesson_date = Date.parse(params[:lesson_date].to_s)

    unless SchoolCalendar::LessonPrompt.school_day?(current_professor, lesson_date)
      render json: { ok: false, error: "Este dia não é letivo." }, status: :unprocessable_entity
      return
    end

    result = Lessons::DayLessonsFromTimetable.new(
      professor: current_professor,
      lesson_date: lesson_date,
      upload: params[:timetable]
    ).call

    unless result[:ok]
      render json: { ok: false, error: result[:error] }, status: :unprocessable_entity
      return
    end

    bimester = SchoolCalendar::LessonPrompt.bimester_label(lesson_date)
    render json: {
      ok: true,
      message: [result[:message], bimester && "As aulas entram no #{bimester}."].compact.join(" "),
      warning: result[:warning],
      classrooms: result[:classrooms],
      diary_url: lessons_path
    }
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

  def day_entries_for(date)
    current_professor.timetable_entries
                     .joins(:classroom)
                     .includes(:classroom, :course)
                     .where(weekday: date.cwday)
                     .order("timetable_entries.period, classrooms.name")
  end

  def tempos_by_weekday
    current_professor.timetable_entries
                     .includes(:classroom)
                     .order(:weekday, :period)
                     .group_by(&:weekday)
                     .transform_values do |rows|
                       rows.map { |entry| "#{entry.period}º · #{entry.classroom.name}" }
                     end
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

end
