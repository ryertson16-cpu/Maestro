module Billing
  module Config
    module_function

    MONTHLY_PRICE = BigDecimal("49.90")
    ANNUAL_PRICE = BigDecimal("499.00")
    TRIAL_DAYS = 7
    GRACE_DAYS = 3

    def enforced?
      return ActiveModel::Type::Boolean.new.cast(ENV["MAESTRO_BILLING_ENFORCED"]) if ENV.key?("MAESTRO_BILLING_ENFORCED")

      Rails.env.production?
    end

    def asaas_api_key
      ENV["ASAAS_API_KEY"].presence
    end

    def asaas_configured?
      asaas_api_key.present?
    end

    def asaas_base_url
      ENV.fetch("ASAAS_API_URL", "https://api.asaas.com")
    end

    def webhook_token
      ENV["ASAAS_WEBHOOK_TOKEN"].presence
    end
  end
end
