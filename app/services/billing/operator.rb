module Billing
  module Operator
    module_function

    def owns?(email)
      normalized = email.to_s.strip.downcase
      return false if normalized.blank?

      owner_emails.include?(normalized)
    end

    def owner_emails
      ENV.fetch("MAESTRO_OWNER_EMAILS", "").split(/[,\s]+/).map(&:downcase).reject(&:blank?)
    end
  end
end
