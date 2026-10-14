module SchoolCalendar
  module YearTemplate
    module_function

    def apply(professor, year)
      extras_for(year).each do |date, kind, name|
        day = professor.school_calendar_days.find_or_initialize_by(day: date)
        next if day.persisted? && day.kind == "holiday" && kind != "holiday"

        day.kind = kind
        day.name = name
        day.save!
      end
    end

    def extras_for(year)
      return [] unless year == 2026

      days = []

      (Date.new(2026, 1, 2)..Date.new(2026, 2, 1)).each do |date|
        days << [date, "no_class", "Recesso"]
      end

      [
        [Date.new(2026, 2, 2), "milestone", "Início do ano letivo"],
        [Date.new(2026, 2, 18), "holiday", "Cinzas"],
        [Date.new(2026, 2, 25), "planning", "Planejamento"],
        [Date.new(2026, 3, 6), "holiday", "Recesso"],
        [Date.new(2026, 3, 10), "planning", "Formação"],
        [Date.new(2026, 4, 1), "no_class", "Recesso de Páscoa"],
        [Date.new(2026, 4, 2), "no_class", "Recesso de Páscoa"],
        [Date.new(2026, 5, 20), "milestone", "Marco letivo"],
        [Date.new(2026, 7, 9), "no_class", "Férias"],
        [Date.new(2026, 7, 10), "no_class", "Férias"],
        *july_second_recess,
        [Date.new(2026, 8, 11), "planning", "Formação"],
        [Date.new(2026, 8, 31), "planning", "Planejamento"],
        [Date.new(2026, 9, 13), "planning", "Evento da rede"],
        [Date.new(2026, 10, 15), "milestone", "Marco letivo"],
        [Date.new(2026, 10, 28), "holiday", "Dia do Servidor Público"],
        [Date.new(2026, 11, 26), "planning", "Formação"],
        [Date.new(2026, 12, 22), "planning", "Planejamento"],
        [Date.new(2026, 12, 23), "milestone", "Término do ano letivo"],
        [Date.new(2026, 12, 24), "holiday", "Recesso de Natal"],
        [Date.new(2026, 12, 30), "planning", "Planejamento"],
        [Date.new(2026, 12, 31), "planning", "Planejamento"]
      ].each { |row| days << row }

      (Date.new(2026, 12, 26)..Date.new(2026, 12, 29)).each do |date|
        days << [date, "no_class", "Recesso"]
      end

      days
    end

    def july_second_recess
      (Date.new(2026, 7, 20)..Date.new(2026, 7, 24)).map do |date|
        [date, "no_class", "Férias"]
      end
    end
  end
end
