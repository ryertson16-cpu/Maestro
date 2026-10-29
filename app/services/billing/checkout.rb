module Billing
  class Checkout
    def initialize(professor)
      @professor = professor
    end

    def start_monthly!(payment_method: "pix")
      method = Payment.normalize(payment_method) || "pix"
      subscription = @professor.subscription || @professor.build_subscription
      subscription.plan = "monthly"
      subscription.payment_method = method

      if Config.asaas_configured?
        Asaas.new.ensure_monthly_subscription!(@professor, subscription, payment_method: method)
      else
        activate_local_preview!(subscription, method)
      end

      subscription.save!
      subscription
    end

    private

    def activate_local_preview!(subscription, method)
      raise "Asaas não configurado." if Rails.env.production?

      subscription.assign_attributes(
        status: "active",
        plan: "monthly",
        payment_method: method,
        last_payment_at: Time.current,
        current_period_end: 1.month.from_now,
        asaas_checkout_url: nil
      )
    end
  end
end
