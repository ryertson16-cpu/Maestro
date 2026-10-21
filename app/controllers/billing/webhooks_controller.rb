module Billing
  class WebhooksController < ActionController::Base
    skip_before_action :verify_authenticity_token

    def create
      return head :unauthorized unless authentic_webhook?

      Webhook.new(params.to_unsafe_h).process!
      head :ok
    rescue StandardError => error
      Rails.logger.error("[Billing] webhook: #{error.class}: #{error.message}")
      head :unprocessable_entity
    end

    private

    def authentic_webhook?
      expected = Config.webhook_token
      return true if expected.blank? && !Rails.env.production?

      given = request.headers["asaas-access-token"].to_s
      expected.present? &&
        given.bytesize == expected.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(given, expected)
    end
  end
end
