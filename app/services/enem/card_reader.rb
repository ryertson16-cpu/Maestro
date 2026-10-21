module Enem
  class CardReader
    Scan = Struct.new(:name, :letters, :source, keyword_init: true) do
      def filled_count
        Array(letters).count { |letter| Question::LETTERS.include?(letter) }
      end
    end

    def self.read(path, filename: nil, roster: [], vision: nil)
      text = Enem::KeyParser.from_pdf(path)
      from_file = Lessons::NameMatcher.match_student(
        File.basename(filename.to_s, ".*"),
        roster
      )
      skip_vision = from_file.present? && text.filled_count >= 40
      use_vision = vision.nil? ? Lira.llm_enabled? : vision
      seen = Enem::CardVision.scan(path) if use_vision && Lira.llm_enabled? && !skip_vision

      letters = text.letters
      source = text.source
      if seen && seen.filled_count > text.filled_count
        letters = seen.letters
        source = "lira"
      end

      Scan.new(name: seen&.name, letters: letters, source: source)
    end
  end
end
