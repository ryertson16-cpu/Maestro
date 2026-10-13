require "openssl"

module Lira
  class WhatsappWebhooksController < ActionController::Base
    skip_before_action :verify_authenticity_token

    def verify
      if params["hub.mode"] == "subscribe" &&
         Lira.whatsapp_verify_token.present? &&
         params["hub.verify_token"].to_s.bytesize == Lira.whatsapp_verify_token.bytesize &&
         ActiveSupport::SecurityUtils.secure_compare(
           params["hub.verify_token"].to_s,
           Lira.whatsapp_verify_token
         )
        render plain: params["hub.challenge"]
      else
        head :forbidden
      end
    end

    def receive
      return head :unauthorized unless valid_signature?

      Lira::Whatsapp.extract_incoming(webhook_payload).each do |incoming|
        Lira::ProcessWhatsappJob.perform_later(
          incoming[:wa_id],
          incoming[:text],
          incoming[:message_id]
        )
      end

      head :ok
    end

    private

    def webhook_payload
      if params[:entry].present?
        params.permit!.to_h
      else
        JSON.parse(request.raw_post)
      end
    rescue JSON::ParserError
      {}
    end

    def valid_signature?
      secret = Lira.whatsapp_app_secret
      return true if secret.blank?

      payload = webhook_raw_body
      signature = hub_signature
      expected = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, payload)}"
      valid = signature.present? &&
              signature.bytesize == expected.bytesize &&
              ActiveSupport::SecurityUtils.secure_compare(signature, expected)

      return true if valid

      if Rails.env.development?
        Rails.logger.warn("[Lira] Assinatura do webhook da Meta não conferiu; em development o POST segue.")
        return true
      end

      false
    end

    def hub_signature
      request.headers["X-Hub-Signature-256"].to_s.presence ||
        request.get_header("HTTP_X_HUB_SIGNATURE_256").to_s
    end

    def webhook_raw_body
      body = request.raw_post.to_s
      return body if body.present?

      request.body.rewind
      request.body.read.to_s
    end
  end
end
