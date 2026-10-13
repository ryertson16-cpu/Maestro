module Monitoring
  class StudentAlert
    attr_reader :student,
                :classroom,
                :month,
                :pending_activities,
                :unscored_activities,
                :grade_alerts,
                :attendance_percentage,
                :attendance_alert,
                :late_alert,
                :trajectory_alert

    def initialize(student:, classroom:, month:, pending_activities:, grade_alerts:, attendance_percentage:, attendance_alert:, late_alert: nil, trajectory_alert: nil, unscored_activities: [])
      @student = student
      @classroom = classroom
      @month = month
      @pending_activities = pending_activities
      @unscored_activities = unscored_activities
      @grade_alerts = grade_alerts
      @attendance_percentage = attendance_percentage
      @attendance_alert = attendance_alert
      @late_alert = late_alert
      @trajectory_alert = trajectory_alert
    end

    def alerted?
      pending_activities.any? ||
        unscored_activities.any? ||
        grade_alerts.any? ||
        attendance_alert.present? ||
        late_alert.present?
    end

    def tags
      items = []

      if pending_activities.any?
        items << { tone: "danger", label: "Cuidado, há atividade(s) não entregue(s)" }
      end

      if unscored_activities.any?
        items << { tone: "danger", label: "Cuidado, notas não lançadas" }
      end

      if grade_alerts.any? { |alert| alert[:severity] == :danger }
        items << { tone: "danger", label: "Cuidado, média abaixo de 4" }
      end

      if attendance_alert&.dig(:severity) == :danger
        items << { tone: "danger", label: "Cuidado, frequência abaixo de 75%" }
      end

      if grade_alerts.any? { |alert| alert[:severity] == :warning }
        items << { tone: "warning", label: "Atenção, média entre 4 e 6" }
      end

      if attendance_alert&.dig(:severity) == :warning
        items << { tone: "warning", label: "Atenção, frequência entre 75% e 80%" }
      end

      if late_alert.present?
        items << { tone: "late", label: "Atenção, chegando atrasado" }
      end

      items << { tone: "ok", label: "Em dia" } if items.empty?
      items
    end

    def severity
      return :none unless alerted?
      return :danger if pending_activities.any?
      return :danger if unscored_activities.any?
      return :danger if grade_alerts.any? { |alert| alert[:severity] == :danger }
      return :danger if attendance_alert&.dig(:severity) == :danger

      :warning
    end

    def severity_label
      return "Em dia" unless alerted?

      severity == :danger ? "Cuidado" : "Atenção"
    end

    def matches_filter?(filter)
      return false unless alerted?

      case filter.to_s
      when "danger" then severity == :danger
      when "activities" then pending_activities.any?
      when "grades" then grade_alerts.any? || unscored_activities.any?
      when "attendance" then attendance_alert.present? || late_alert.present?
      else true
      end
    end

    def recado_text
      lines = [
        "Olá! Gostaria de conversar sobre o acompanhamento de #{student.name} na turma #{classroom.name} (#{month_label}).",
        ""
      ]

      if pending_activities.any?
        lines << "Atividades não entregues:"
        pending_activities.each do |item|
          activity = item[:activity]
          due = activity.due_date.present? ? I18n.l(activity.due_date, format: :short) : "sem data"
          lines << "- #{activity.title} (limite: #{due})"
        end
        lines << ""
      end

      if unscored_activities.any?
        lines << "Notas ainda não lançadas:"
        unscored_activities.each do |item|
          activity = item[:activity]
          lines << "- #{activity.title}"
        end
        lines << ""
      end

      if grade_alerts.any?
        lines << "Notas abaixo do esperado:"
        grade_alerts.each do |alert|
          score = format("%.1f", alert[:final_score])
          lines << "- #{alert[:bimester]}º bimestre: #{score} (#{alert[:label]})"
        end
        lines << ""
      end

      if attendance_alert.present?
        lines << "Frequência: #{attendance_percentage}% — #{attendance_alert[:reason]}."
        lines << ""
      end

      if late_alert.present?
        lines << late_alert[:reason]
        lines << ""
      end

      lines << "Podemos alinhar os próximos passos."
      lines.join("\n")
    end

    def whatsapp_url
      "https://wa.me/?text=#{ERB::Util.url_encode(recado_text)}"
    end

    def to_legacy_row
      {
        student: student,
        pending_activities: pending_activities,
        unscored_activities: unscored_activities,
        grade_alerts: grade_alerts,
        attendance_percentage: attendance_percentage,
        attendance_alert: attendance_alert
      }
    end

    private

    def month_label
      I18n.l(month, format: "%B de %Y").capitalize
    end
  end
end
