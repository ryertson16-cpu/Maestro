module Activities
  class CardMark
    KINDS = {
      hit: "green",
      miss: "red",
      blank: "blue"
    }.freeze

    def self.marks(activity:, student:, position_answers:, bubbles:)
      rows = ExamAssigner.new(activity).presented_for(student)
      answers = (position_answers || {}).stringify_keys
      points = normalize_bubbles(bubbles)

      rows.filter_map do |row|
        next unless row.item.objective?

        correct = row.printed_correct.to_s.upcase
        marked = answers[row.number.to_s].to_s.upcase
        kind = if marked.blank?
          :blank
        elsif marked == correct
          :hit
        else
          :miss
        end
        point = points.dig(row.number.to_s, correct)
        next unless point

        { x: point[0], y: point[1], kind: kind, number: row.number, letter: correct }
      end
    end

    def self.normalize_bubbles(raw)
      mapped = {}
      (raw || {}).each do |number, letters|
        key = number.to_s
        mapped[key] = {}
        next unless letters.respond_to?(:each)

        letters.each do |letter, pair|
          coords = Array(pair).first(2).map { |value| value.to_s.tr(",", ".").to_f }
          next unless coords.size == 2
          next unless coords.all? { |value| value >= 0 }

          mapped[key][letter.to_s.upcase] =
            if coords.all? { |value| value <= 1 }
              coords
            elsif coords.all? { |value| value <= 100 }
              coords.map { |value| value / 100.0 }
            end
          mapped[key].delete(letter.to_s.upcase) if mapped[key][letter.to_s.upcase].blank?
        end
      end
      mapped
    end
  end
end
