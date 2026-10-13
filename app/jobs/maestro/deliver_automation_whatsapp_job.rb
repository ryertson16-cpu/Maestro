module Maestro
  class DeliverAutomationWhatsappJob < ApplicationJob
    queue_as :default

    def perform(notice_id)
      notice = AutomationNotice.find_by(id: notice_id)
      return if notice.blank?
      return if notice.whatsapp_sent_at.present?

      professor = notice.professor
      return if professor.whatsapp_number.blank?
      return unless Lira.whatsapp_enabled?

      body = [
        "Maestro · #{notice.title}",
        notice.body,
        "Responda *hoje* ou *ajuda*."
      ].join("\n\n")

      sent = Lira::Whatsapp.reply(
        to: Lira::Phone.e164(professor.whatsapp_number),
        body: body
      )
      notice.update!(whatsapp_sent_at: Time.current) if sent
    end
  end
end
