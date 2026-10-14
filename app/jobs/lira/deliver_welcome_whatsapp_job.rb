module Lira
  class DeliverWelcomeWhatsappJob < ApplicationJob
    queue_as :default

    def perform(professor_id)
      professor = Professor.find_by(id: professor_id)
      return if professor.blank?
      return unless professor.needs_whatsapp_welcome?
      return unless Lira.whatsapp_enabled?

      sent = Lira::Whatsapp.reply(
        to: Lira::Phone.e164(professor.whatsapp_number),
        body: Lira.whatsapp_welcome_message(professor)
      )
      return unless sent

      professor.update_column(:whatsapp_welcome_sent_at, Time.current)
    end
  end
end
