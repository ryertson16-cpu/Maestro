module Maestro
  class ReminderCard
    def initialize(reminder, now: Time.zone.now)
      @reminder = reminder
      @now = now
    end

    def as_json(*)
      {
        id: @reminder.id,
        title: @reminder.title,
        time_label: @reminder.remind_at.strftime("%H:%M"),
        weekday_label: weekday_label,
        date_label: I18n.l(@reminder.remind_at.to_date),
        when_label: when_label,
        remain_label: remain_label
      }
    end

    private

    def weekday_label
      names = {
        1 => "segunda",
        2 => "terça",
        3 => "quarta",
        4 => "quinta",
        5 => "sexta",
        6 => "sábado",
        7 => "domingo"
      }
      names[@reminder.remind_at.to_date.cwday]
    end

    def when_label
      days = (@reminder.remind_at.to_date - @now.to_date).to_i
      case days
      when 0 then "hoje"
      when 1 then "amanhã"
      else weekday_label
      end
    end

    def remain_label
      days = (@reminder.remind_at.to_date - @now.to_date).to_i
      if days <= 0
        minutes = ((@reminder.remind_at - @now) / 60).round
        return "agora" if minutes <= 1
        return "em #{minutes} min" if minutes < 60

        hours = (minutes / 60.0).round
        hours == 1 ? "em 1 hora" : "em #{hours} horas"
      elsif days == 1
        "falta 1 dia"
      else
        "faltam #{days} dias"
      end
    end
  end
end
