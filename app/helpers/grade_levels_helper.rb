module GradeLevelsHelper
  ACTIVITY_STATUS_LABELS = {
    delivered: "Entregue",
    delivered_late: "Entregue com atraso",
    in_progress: "Em andamento",
    not_delivered: "Não entregou"
  }.freeze

  def activity_status_label(status)
    ACTIVITY_STATUS_LABELS.fetch(status.to_sym, status.to_s.humanize)
  end
end
