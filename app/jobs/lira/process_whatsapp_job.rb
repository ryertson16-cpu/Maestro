module Lira
  class ProcessWhatsappJob < ApplicationJob
    queue_as :default

    def perform(wa_id, text, message_id)
      Lira::Whatsapp.handle_incoming(
        wa_id: wa_id,
        text: text,
        message_id: message_id
      )
    end
  end
end
