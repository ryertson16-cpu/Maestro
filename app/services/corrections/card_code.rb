module Corrections
  class CardCode
    PATTERN = /\AM(\d{6})(?:A(\d+))?(?:F(\d+))?\z/i

    def self.payload(activity, student = nil, slot: nil)
      pin = activity.ensure_correction_pin!
      return "M#{pin}" if student.nil?

      code = "M#{pin}A#{student.id}"
      return code if slot.blank?

      "#{code}F#{slot}"
    end

    def self.parse(text)
      compact = text.to_s.upcase.gsub(/[^A-Z0-9]/, "")
      match = compact.match(PATTERN)
      return if match.blank?

      {
        pin: match[1],
        student_id: match[2].presence&.to_i,
        slot: match[3].presence&.to_i
      }
    end
  end
end
