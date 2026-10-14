module Monitoring
  module Trajectory
    module_function

    def call(records:, month:, today: Date.current)
      school_days = weekdays_in(month)
      return if school_days.zero? || records.blank?

      absences = records.count { |record| record.respond_to?(:absent?) ? record.absent? : record.status.to_s == "absent" }
      total = records.size
      percentage = ((total - absences).to_f / total * 100).round(1)
      allowed = (school_days * 0.25).floor
      remaining_absences = allowed - absences
      remaining_days = [school_days - total, 0].max

      if percentage < 75
        return
      end

      return if remaining_absences > 3
      return if remaining_days.zero? && remaining_absences.positive?

      projected = if remaining_absences.negative?
                    percentage
                  else
                    extra = [remaining_absences + 1, remaining_days].min
                    next_total = total + extra
                    next_absences = absences + extra
                    ((next_total - next_absences).to_f / next_total * 100).round(1)
                  end

      {
        severity: :warning,
        label: "Risco à frente",
        reason: if remaining_absences <= 0
                  "Não há mais margem de faltas neste mês para permanecer em 75%."
                else
                  "Mais #{remaining_absences} falta(s) neste mês e a frequência cai de #{percentage}% para cerca de #{projected}%."
                end
      }
    end

    def weekdays_in(month)
      first = month.beginning_of_month
      last = month.end_of_month
      (first..last).count(&:on_weekday?)
    end
  end
end
