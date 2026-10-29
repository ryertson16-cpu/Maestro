module Desk
  class Lookup
    def initialize(whatsapp)
      @whatsapp = whatsapp
    end

    def payload
      professor = Professor.find_by_whatsapp(@whatsapp)
      return { found: false, whatsapp: digits } if professor.blank?

      subscription = professor.subscription
      {
        found: true,
        whatsapp: digits,
        greeting_name: professor.greeting_name,
        role: professor.courtesy_role,
        email: professor.email,
        school: professor.school&.name,
        full_access: professor.maestro_full_access?,
        subscription: {
          status: subscription&.status,
          label: subscription&.label,
          plan: subscription&.plan,
          payment: subscription&.payment_label,
          period_end: subscription&.current_period_end&.iso8601
        }
      }
    end

    private

    def digits
      Lira::Phone.digits(@whatsapp).presence
    end
  end
end
