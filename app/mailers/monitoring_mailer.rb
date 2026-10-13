class MonitoringMailer < ApplicationMailer
  default from: "Maestro <nao-responda@maestro.local>"

  def digest(professor:, classroom:, month:, alerts:)
    @professor = professor
    @classroom = classroom
    @month = month
    @alerts = alerts
    @month_label = I18n.l(month, format: "%B de %Y").capitalize

    mail(
      to: professor.email,
      subject: "Alertas de monitoramento — #{classroom.name} (#{@month_label})"
    )
  end
end
