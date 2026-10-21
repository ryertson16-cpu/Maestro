module Billing
  class Checkout
    def initialize(professor)
      @professor = professor
    end

    def start_monthly!
      subscription = @professor.subscription || @professor.build_subscription
      subscription.plan = "monthly"

      if Config.asaas_configured?
        Asaas.new.ensure_monthly_subscription!(@professor, subscription)
      else
        activate_local_preview!(subscription)
      end

      subscription.save!
      subscription
    end

    private

    def activate_local_preview!(subscription)
      raise "Asaas não configurado." if Rails.env.production?

      subscription.assign_attributes(
        status: "active",
        plan: "monthly",
        last_payment_at: Time.current,
        current_period_end: 1.month.from_now,
        asaas_checkout_url: nil
      )
    end
  end
end
