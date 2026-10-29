module SchoolCalendar
  class SeeImporter
    def initialize(professor:, upload:)
      @professor = professor
      @upload = upload
    end

    def call
      parsed = SeeParser.new(@upload).parse
      saved = 0

      SchoolCalendarDay.transaction do
        range = Date.new(parsed.year, 1, 1)..Date.new(parsed.year, 12, 31)
        @professor.school_calendar_days.where(day: range).delete_all

        parsed.cells.each do |date, code|
          mark = Marks.from_see_code(
            code,
            date: date,
            holiday_name: parsed.holiday_names[date]
          )
          next if mark == :skip || mark == :plain

          @professor.school_calendar_days.create!(
            day: date,
            kind: mark[:kind],
            name: mark[:name]
          )
          saved += 1
        end
      end

      {
        ok: true,
        year: parsed.year,
        count: saved,
        message: "Calendário da SEE de #{parsed.year} aplicado (#{saved} marcas). A grade continua a mesma: clique num dia para ajustar com as legendas."
      }
    rescue ArgumentError => error
      { ok: false, error: error.message }
    end
  end
end
