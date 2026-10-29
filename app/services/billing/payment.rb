module Billing
  module Payment
    METHODS = {
      "pix" => "PIX",
      "credit_card" => "Cartão"
    }.freeze

    ASAAS_TYPES = {
      "pix" => "PIX",
      "credit_card" => "CREDIT_CARD"
    }.freeze

    module_function

    def normalize(value)
      key = value.to_s.strip.downcase
      return key if METHODS.key?(key)

      from_asaas(value)
    end

    def label(value)
      METHODS[normalize(value)] || "—"
    end

    def asaas_type(value)
      ASAAS_TYPES.fetch(normalize(value) || "pix")
    end

    def from_asaas(value)
      case value.to_s.upcase
      when "PIX" then "pix"
      when "CREDIT_CARD", "DEBIT_CARD" then "credit_card"
      end
    end
  end
end
