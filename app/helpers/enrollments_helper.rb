module EnrollmentsHelper
  def enrollment_caderno_tag(enrollment)
    label = enrollment&.caderno_tag
    return if label.blank?

    content_tag(:span, label, class: "monitoring-classroom-badge")
  end
end
