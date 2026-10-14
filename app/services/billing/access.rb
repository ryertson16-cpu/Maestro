module Billing
  module Access
    module_function

    def allowed?(professor)
      return true unless Config.enforced?
      return false if professor.blank?

      subscription = professor.subscription
      return false if subscription.blank?

      return true if subscription.complimentary?
      return true if subscription.active? && period_open?(subscription)
      return true if subscription.trialing? && period_open?(subscription, subscription.trial_ends_at)
      return true if subscription.past_due? && within_grace?(subscription)

      false
    end

    def period_open?(subscription, limit = subscription.current_period_end)
      limit.blank? || limit > Time.current
    end

    def within_grace?(subscription)
      ends = subscription.current_period_end
      return false if ends.blank?

      Time.current <= ends + Config::GRACE_DAYS.days
    end

    def blocked_whatsapp_message
      "Sua assinatura do Maestro não está ativa. Renove em #{public_host} para voltar a consultar o caderno pelo WhatsApp."
    end

    def public_host
      ENV.fetch("MAESTRO_PUBLIC_HOST", "https://maestro.com.br")
    end
  end
end
