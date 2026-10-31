module Corrections
  class CardCode
    PATTERN = /\AM(\d{6})(?:A(\d+))?\z/i

    def self.payload(activity, student = nil)
      pin = activity.ensure_correction_pin!
      return "M#{pin}A#{student.id}" if student

      "M#{pin}"
    end

    def self.parse(text)
      compact = text.to_s.upcase.gsub(/[^A-Z0-9]/, "")
      match = compact.match(PATTERN)
      return if match.blank?

      {
        pin: match[1],
        student_id: match[2].presence&.to_i
      }
    end
  end
end
