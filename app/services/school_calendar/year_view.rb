module SchoolCalendar
  class YearView
    WEEKDAYS = %w[Dom Seg Ter Qua Qui Sex Sáb].freeze
    MONTHS = %w[
      Janeiro Fevereiro Março Abril Maio Junho
      Julho Agosto Setembro Outubro Novembro Dezembro
    ].freeze

    DayCell = Data.define(:date, :label, :kind, :name, :school_day, :css)

    MonthGrid = Data.define(:number, :name, :leading_blanks, :days, :school_days)

    def initialize(year:, marked_days:)
      @year = year
      @marks = Array(marked_days).index_by(&:day)
    end

    attr_reader :year

    def months
      @months ||= (1..12).map { |month| build_month(month) }
    end

    def weekday_matrix
      counts = Array.new(5) { Array.new(12, 0) }

      months.each do |month|
        next if skip_january_in_summary? && month.number == 1

        month.days.each do |cell|
          next unless cell.school_day
          next unless (1..5).cover?(cell.date.cwday)

          counts[cell.date.cwday - 1][month.number - 1] += 1
        end
      end

      counts
    end

    def weekday_totals
      weekday_matrix.map(&:sum)
    end

    def month_totals
      months.map(&:school_days)
    end

    def year_total
      month_totals.sum
    end

    def weekday_year_total
      weekday_totals.sum
    end

    def skip_january_in_summary?
      year == 2026
    end

    def school_day?(date)
      mark = @marks[date]
      return false if mark&.blocks_lessons?
      return true if mark&.kind == "saturday_school"
      return false if date.saturday? || date.sunday?

      true
    end

    def css_for(date)
      mark = @marks[date]
      return "is-saturday" if mark&.kind == "saturday_school"
      return "is-holiday" if mark&.kind == "holiday"
      return "is-recess" if mark&.kind == "no_class"
      return "is-planning" if mark&.kind == "planning"
      return "is-milestone" if mark&.kind == "milestone"
      return "is-weekend" if date.saturday? || date.sunday?

      ["is-school", bimester_css(date)].compact.join(" ")
    end

    def bimester_css(date)
      number = SchoolCalendar::LessonPrompt.bimester_number(date)
      return if number.blank?

      "is-bimester-#{number}"
    end

    private

    def build_month(month)
      start = Date.new(@year, month, 1)
      stop = start.end_of_month
      days = (start..stop).map do |date|
        mark = @marks[date]
        DayCell.new(
          date: date,
          label: date.day,
          kind: mark&.kind,
          name: mark&.name,
          school_day: school_day?(date),
          css: css_for(date)
        )
      end

      MonthGrid.new(
        number: month,
        name: MONTHS[month - 1],
        leading_blanks: start.wday,
        days: days,
        school_days: days.count(&:school_day)
      )
    end
  end
end
