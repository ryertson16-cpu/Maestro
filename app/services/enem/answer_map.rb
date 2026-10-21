module Enem
  module AnswerMap
    module_function

    def from(raw)
      letters = Array.new(Enem::ScoreScale::QUESTION_COUNT)

      case raw
      when Array
        values = raw
        offset = values.size >= 180 ? 90 : 0
        Enem::ScoreScale::QUESTION_COUNT.times do |index|
          letters[index] = letter(values[offset + index])
        end
      when Hash
        numbered = {}
        raw.each do |key, value|
          number = key.to_s.to_i
          next unless number.positive?

          numbered[number] = letter(value)
        end
        source = numbered.keys.any? { |number| number >= 91 } ? numbered.select { |number, _| number >= 91 } : numbered
        source.each do |number, value|
          index = number >= 91 ? number - 90 : number
          next unless index.between?(1, Enem::ScoreScale::QUESTION_COUNT)

          letters[index - 1] = value
        end
      end

      letters
    end

    def letter(value)
      item = value.to_s.strip.upcase
      Question::LETTERS.include?(item) ? item : nil
    end
  end
end
