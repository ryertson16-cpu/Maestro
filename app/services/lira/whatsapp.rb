require "json"
require "net/http"
require "uri"

module Lira
  module Whatsapp
    module_function

    # Casca do WhatsApp: identifica o professor pelo número e chama
    # a mesma Lira::Responder do chat do site. Um único número da API
    # atende todos; o isolamento é o cadastro whatsapp_number.
    def handle_incoming(wa_id:, text:, message_id: nil)
      return if already_processed?(message_id)

      professor = Professor.find_by_whatsapp(wa_id)
      unless professor
        Rails.logger.warn("[Lira] WhatsApp #{wa_id} não bate com nenhum professor.")
        reply(to: wa_id, body: unknown_number_message)
        return
      end

      unless professor.maestro_full_access?
        reply(to: wa_id, body: Billing::Access.blocked_whatsapp_message)
        return
      end

      conversation = professor.lira_conversation_for(
        channel: "whatsapp",
        external_id: wa_id
      )

      answer = Lira::Responder.new(
        professor: professor,
        conversation: conversation
      ).reply(
        text.to_s,
        metadata: { whatsapp_message_id: message_id, wa_id: wa_id }
      )

      destination = Lira::Phone.e164(professor.whatsapp_number).presence || wa_id
      Rails.logger.info("[Lira] WhatsApp resposta para #{destination} (wa_id #{wa_id})")
      reply(to: destination, body: answer)
    end

    def extract_incoming(payload)
      entries = Array(payload["entry"] || payload[:entry])
      entries.flat_map do |entry|
        Array(entry["changes"] || entry[:changes]).flat_map do |change|
          value = change["value"] || change[:value] || {}
          Array(value["messages"] || value[:messages]).filter_map do |message|
            text = message.dig("text", "body") || message.dig(:text, :body)
            next if text.blank?

            {
              wa_id: message["from"] || message[:from],
              text: text,
              message_id: message["id"] || message[:id]
            }
          end
        end
      end
    end

    def reply(to:, body:)
      unless Lira.whatsapp_enabled?
        Rails.logger.warn("[Lira] WhatsApp desligado: falta LIRA_WHATSAPP_TOKEN ou PHONE_NUMBER_ID.")
        return false
      end
      return false if to.blank? || body.blank?

      uri = URI.parse(
        "https://graph.facebook.com/v21.0/#{Lira.whatsapp_phone_number_id}/messages"
      )
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{Lira.whatsapp_token}"
      request["Content-Type"] = "application/json"
      request.body = {
        messaging_product: "whatsapp",
        to: to,
        type: "text",
        text: { body: body, preview_url: false }
      }.to_json

      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("[Lira] WhatsApp Graph #{response.code}: #{response.body.to_s.truncate(500)}")
        return false
      end

      true
    rescue StandardError => error
      Rails.logger.warn("[Lira] WhatsApp envio: #{error.class} #{error.message}")
      false
    end

    def unknown_number_message
      "Olá! Eu sou o Maestro. Este número ainda não está vinculado à sua conta. Entre no caderno, abra Configurações e informe o WhatsApp com DDD."
    end

    def already_processed?(message_id)
      return false if message_id.blank?

      scope = AgentMessage.all
      if AgentMessage.connection.adapter_name.match?(/postg/i)
        scope.where("metadata->>'whatsapp_message_id' = ?", message_id).exists?
      else
        scope.where("json_extract(metadata, '$.whatsapp_message_id') = ?", message_id).exists?
      end
    end
  end
end
