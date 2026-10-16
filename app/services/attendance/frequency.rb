module Attendance
  module Frequency
    MINIMUM = 75

    module_function

    def percentage(records)
      list = Array(records)
      return if list.empty?

      absences = list.count { |record| absent?(record) }
      ((list.size - absences).to_f / list.size * 100).round(1)
    end

    def snapshot(records)
      list = Array(records)
      value = percentage(list)

      {
        total: list.size,
        present: list.count { |record| status?(record, "present") },
        absent: list.count { |record| absent?(record) },
        justified: list.count { |record| status?(record, "justified") },
        late: list.count { |record| status?(record, "late") },
        percentage: value,
        situation: situation(value)
      }
    end

    def situation(value)
      return "without_records" if value.nil?
      return "regular" if value >= MINIMUM
      return "attention" if value >= 50

      "low"
    end

    def below_minimum?(value)
      value.present? && value < MINIMUM
    end

    def month_range(month = Date.current)
      day = month.to_date.beginning_of_month
      day.all_month
    end

    def absent?(record)
      return record.absent? if record.respond_to?(:absent?)

      record.status.to_s == "absent"
    end

    def status?(record, status)
      return record.public_send("#{status}?") if record.respond_to?("#{status}?")

      record.status.to_s == status
    end
  end
end
