module Maestro
  class TodayBriefing
    Slot = Data.define(:entry, :lesson, :called)
    WeekDay = Data.define(:date, :short_label, :name, :current, :past, :school_day)

    WEEK_SHORT_LABELS = {
      1 => "Seg",
      2 => "Ter",
      3 => "Qua",
      4 => "Qui",
      5 => "Sex",
      6 => "Sáb",
      7 => "Dom"
    }.freeze

    WEEK_NAMES = {
      1 => "Segunda-feira",
      2 => "Terça-feira",
      3 => "Quarta-feira",
      4 => "Quinta-feira",
      5 => "Sexta-feira",
      6 => "Sábado",
      7 => "Domingo"
    }.freeze

    def initialize(professor:, date: Date.current)
      @professor = professor
      @date = date.to_date
    end

    attr_reader :date

    def weekday_label
      if weekday.between?(1, 6)
        TimetableEntry::WEEKDAY_LABELS.fetch(weekday)
      else
        "Domingo"
      end
    end

    def period_label
      Siage.period_for_date(@date)
    end

    def calendar_day
      @calendar_day ||= @professor.school_calendar_days.find_by(day: @date)
    end

    def blocks_lessons?
      !school_day?
    end

    def school_day?
      return @school_day if defined?(@school_day)

      @school_day = school_day_for?(@date, calendar_day)
    end

    def week_days
      @week_days ||= begin
        monday = @date.beginning_of_week(:monday)
        span = monday..(monday + 6)
        marks = @professor.school_calendar_days.where(day: span).index_by(&:day)

        span.map do |day|
          cwday = day.cwday
          WeekDay.new(
            date: day,
            short_label: WEEK_SHORT_LABELS.fetch(cwday),
            name: WEEK_NAMES.fetch(cwday),
            current: day == @date,
            past: day < @date,
            school_day: school_day_for?(day, marks[day])
          )
        end
      end
    end

    def slots
      return [] unless school_day?

      @slots ||= timetable_entries.map do |entry|
        lesson = lessons_today.find do |item|
          item.classroom_id == entry.classroom_id &&
            (item.siage_time_slot.blank? || item.siage_time_slot == entry.time_slot_label)
        end

        Slot.new(
          entry: entry,
          lesson: lesson,
          called: called_classroom_ids.include?(entry.classroom_id)
        )
      end
    end

    def classrooms_waiting_call
      return [] unless school_day?

      rooms = @professor
              .classrooms
              .where(active: true, id: enrolled_classroom_ids)
              .where.not(id: called_classroom_ids)
              .order(:name)

      timed = rooms.select { |classroom| slot_classroom_ids.include?(classroom.id) }
      timed.any? ? timed : rooms.limit(6)
    end

    def lessons_today
      @lessons_today ||= @professor
                         .lessons
                         .includes(:classroom, :course)
                         .where(lesson_date: @date)
                         .order(:created_at)
                         .to_a
    end

    def siage_pending_rows
      @siage_pending_rows ||= ledger.rows.select { |row| row.status.in?(%w[pending exported failed]) }.first(4)
    end

    def siage_pending_count
      ledger.summary[:pending].to_i
    end

    def siage_failed_count
      ledger.summary[:failed].to_i
    end

    def monitoring_alert_count
      @monitoring_alert_count ||= Monitoring::AlertReport.new(professor: @professor).total_alert_count.to_i
    end

    def overdue_projects_count
      @overdue_projects_count ||= Project.overdue_for(@professor).count
    end

    def active_projects_count
      @active_projects_count ||= @professor.projects.where(status: %w[draft active]).count
    end

    def work_pending?
      classrooms_waiting_call.any? ||
        siage_pending_count.positive? ||
        siage_failed_count.positive? ||
        monitoring_alert_count.positive?
    end

    private

    def weekday
      @date.cwday
    end

    def school_day_for?(date, mark)
      return false if mark&.blocks_lessons?
      return true if mark&.kind == "saturday_school"
      return false if date.saturday? || date.sunday?

      true
    end

    def ledger
      @ledger ||= Siage::Ledger.new(professor: @professor)
    end

    def timetable_entries
      return TimetableEntry.none unless weekday.between?(1, 6)

      @timetable_entries ||= @professor
                             .timetable_entries
                             .includes(:classroom, :course)
                             .where(weekday: weekday)
                             .order(:period)
                             .to_a
    end

    def slot_classroom_ids
      @slot_classroom_ids ||= timetable_entries.map(&:classroom_id).uniq
    end

    def called_classroom_ids
      @called_classroom_ids ||= AttendanceRecord
                                .joins(:enrollment)
                                .where(professor: @professor, attendance_date: @date)
                                .distinct
                                .pluck("enrollments.classroom_id")
    end

    def enrolled_classroom_ids
      @enrolled_classroom_ids ||= Enrollment
                                  .where(professor: @professor, status: "active")
                                  .distinct
                                  .pluck(:classroom_id)
    end
  end
end
