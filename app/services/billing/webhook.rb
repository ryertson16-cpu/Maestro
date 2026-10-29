module Billing
  class Webhook
    def initialize(payload)
      @payload = payload.to_h.deep_stringify_keys
    end

    def process!
      event_type = @payload["event"].to_s
      payment = @payload["payment"] || {}
      subscription_data = @payload["subscription"] || {}
      external_id = payment["id"].presence || subscription_data["id"].presence || @payload["id"]

      professor = find_professor(payment, subscription_data)
      BillingEvent.create!(
        professor: professor,
        provider: "asaas",
        event_type: event_type,
        external_id: external_id,
        payload: @payload
      )
      return if professor.blank?

      subscription = professor.subscription || professor.build_subscription(plan: "monthly")

      method = Payment.from_asaas(payment["billingType"] || subscription_data["billingType"])

      case event_type
      when "PAYMENT_CONFIRMED", "PAYMENT_RECEIVED"
        subscription.assign_attributes(
          status: "active",
          plan: "monthly",
          payment_method: method || subscription.payment_method || "pix",
          last_payment_at: Time.current,
          current_period_end: 1.month.from_now,
          asaas_customer_id: payment["customer"].presence || subscription.asaas_customer_id,
          asaas_subscription_id: payment["subscription"].presence || subscription.asaas_subscription_id
        )
      when "PAYMENT_OVERDUE"
        subscription.status = "past_due"
      when "PAYMENT_DELETED", "SUBSCRIPTION_DELETED", "SUBSCRIPTION_INACTIVATED"
        subscription.status = "canceled"
      end

      subscription.save!
    end

    private

    def find_professor(payment, subscription_data)
      reference = payment["externalReference"].presence ||
                  subscription_data["externalReference"].presence
      if reference.present?
        found = Professor.find_by(id: reference)
        return found if found
      end

      ids = [
        payment["customer"],
        payment["subscription"],
        subscription_data["id"],
        subscription_data["customer"]
      ].compact

      Subscription.find_by(asaas_customer_id: ids)&.professor ||
        Subscription.find_by(asaas_subscription_id: ids)&.professor
    end
  end
end
