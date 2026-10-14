module Lira
  module Phone
    module_function

    def digits(value)
      value.to_s.gsub(/\D/, "")
    end

    def match?(stored, incoming)
      left = digits(stored)
      right = digits(incoming)
      return false if left.length < 10 || right.length < 10

      (variants(left) & variants(right)).any?
    end

    # A Meta às vezes entrega o wa_id sem o 9 extra do celular brasileiro
    # (84991184774 no Maestro vs 558491184774 no webhook).
    def variants(number)
      compact = number.sub(/\A55/, "")
      set = [number, compact]
      if compact.length == 11 && compact[2] == "9"
        set << "#{compact[0, 2]}#{compact[3..]}"
      end
      if compact.length == 10
        set << "#{compact[0, 2]}9#{compact[2..]}"
      end
      set.uniq
    end

    def e164(value)
      number = digits(value)
      return if number.blank?
      return number if number.start_with?("55")

      "55#{number}"
    end
  end
end
