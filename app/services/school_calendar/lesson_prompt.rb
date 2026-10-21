module SchoolCalendar
  module LessonPrompt
    module_function

    WEEKDAYS = {
      1 => "segunda-feira",
      2 => "terça-feira",
      3 => "quarta-feira",
      4 => "quinta-feira",
      5 => "sexta-feira",
      6 => "sábado",
      7 => "domingo"
    }.freeze

    def weekday_name(date)
      WEEKDAYS[date.cwday]
    end

    def bimester_number(date)
      label = Siage.period_for_date(date)
      return if label.blank?

      Siage::PERIODS.index(label).to_i + 1
    end

    def bimester_label(date)
      number = bimester_number(date)
      return if number.blank?

      "#{number}º bimestre"
    end

    def time_slots_text(slots)
      labels = Array(slots).map(&:presence).compact
      return "sem tempo na grade" if labels.empty?

      labels.join(" e ")
    end

    def confirm_phrase(date:, time_slots:)
      parts = [
        weekday_name(date),
        I18n.l(date),
        time_slots_text(time_slots),
        bimester_label(date) || "bimestre não definido"
      ]
      "Deseja criar a aula #{parts.join(", ")}?"
    end

    def school_day?(professor, date)
      mark = professor.school_calendar_days.find_by(day: date)
      return false if mark&.blocks_lessons?
      return true if mark&.kind == "saturday_school"
      return false if date.saturday? || date.sunday?

      true
    end
  end
end
