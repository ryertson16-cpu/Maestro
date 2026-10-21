module Siage
  module ExtensionToken
    PURPOSE = :siage_extension
    TTL = 90.days

    module_function

    def generate(professor)
      Rails.application.message_verifier(PURPOSE).generate(
        {
          "professor_id" => professor.id,
          "exp" => TTL.from_now.to_i
        }
      )
    end

    def professor_for(token)
      return if token.blank?

      payload = Rails.application.message_verifier(PURPOSE).verify(token.to_s)
      return if payload["exp"].to_i < Time.current.to_i

      Professor.find_by(id: payload["professor_id"])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end
  end
end
