require "json"
require "net/http"
require "uri"

module Billing
  class Asaas
    def ensure_monthly_subscription!(professor, subscription, payment_method: "pix")
      customer_id = subscription.asaas_customer_id.presence || create_customer(professor)
      billing_type = Payment.asaas_type(payment_method)
      result = create_subscription(professor, customer_id, billing_type)

      subscription.assign_attributes(
        status: "past_due",
        payment_method: Payment.normalize(payment_method) || "pix",
        asaas_customer_id: customer_id,
        asaas_subscription_id: result["id"],
        asaas_checkout_url: result["invoiceUrl"] || result["paymentLink"]
      )
    end

    def create_customer(professor)
      payload = request(
        :post,
        "/v3/customers",
        {
          name: professor.name,
          email: professor.email,
          mobilePhone: professor.whatsapp_number.presence || professor.phone,
          externalReference: professor.id.to_s
        }
      )
      payload.fetch("id")
    end

    def create_subscription(professor, customer_id, billing_type)
      request(
        :post,
        "/v3/subscriptions",
        {
          customer: customer_id,
          billingType: billing_type,
          value: Config::MONTHLY_PRICE.to_f,
          cycle: "MONTHLY",
          description: "Maestro — assinatura mensal",
          externalReference: professor.id.to_s
        }
      )
    end

    private

    def request(method, path, body)
      uri = URI.parse("#{Config.asaas_base_url}#{path}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"

      request = Net::HTTP::Post.new(uri)
      request["access_token"] = Config.asaas_api_key
      request["Content-Type"] = "application/json"
      request["User-Agent"] = "Maestro/2.0"
      request.body = body.to_json

      response = http.request(request)
      payload = JSON.parse(response.body.presence || "{}")
      unless response.is_a?(Net::HTTPSuccess)
        raise "Asaas recusou (#{response.code}): #{payload['errors'] || payload['message'] || payload}"
      end

      payload
    end
  end
end
