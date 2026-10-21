module Enem
  class KeyParser
    Result = Struct.new(:letters, :source, :text, keyword_init: true) do
      def filled_count
        letters.count { |letter| Question::LETTERS.include?(letter) }
      end
    end

    def self.from_pdf(path)
      text = PDF::Reader.new(path).pages.map { |page| page.text.to_s }.join("\n")
      from_text(text)
    rescue PDF::Reader::MalformedPDFError,
           PDF::Reader::EncryptedPDFError,
           PDF::Reader::UnsupportedFeatureError
      Result.new(letters: blank_letters, source: "manual", text: "")
    end

    def self.from_text(text)
      numbered = {}
      text.to_s.scan(/(?:^|[^\dA-Z])(\d{1,2})\s*[-–.:)\t ]+\s*([ABCDE])\b/i) do |number, letter|
        index = number.to_i
        next unless index.between?(1, Enem::ScoreScale::QUESTION_COUNT)

        numbered[index] = letter.upcase
      end

      if numbered.size >= 40
        letters = (1..Enem::ScoreScale::QUESTION_COUNT).map { |index| numbered[index] }
        return Result.new(letters: letters, source: "pdf", text: text.to_s)
      end

      run = text.to_s.upcase.gsub(/[^ABCDE]/, "")
      if run.length >= Enem::ScoreScale::QUESTION_COUNT
        return Result.new(
          letters: run.chars.first(Enem::ScoreScale::QUESTION_COUNT),
          source: "pdf",
          text: text.to_s
        )
      end

      Result.new(letters: blank_letters, source: "manual", text: text.to_s)
    end

    def self.suggest_with_lira(text)
      excerpt = text.to_s[0, 12_000]
      return if excerpt.blank?

      content = Lira::Brain.new(nil).extract_text(
        <<~PROMPT,
          Extraia as #{Enem::ScoreScale::QUESTION_COUNT} respostas objetivas (A–E) deste gabarito ou cartão.
          Itens 1 a 45 = Ciências da Natureza. Itens 46 a 90 = Matemática.
          Responda só um JSON: {"answers":["A","B",...] } com exatamente #{Enem::ScoreScale::QUESTION_COUNT} letras.

          Texto:
          #{excerpt}
        PROMPT
        system: "Você só extrai gabaritos ENEM. Não invente item que o texto não mostre. Use null se faltar."
      )
      letters = letters_from_json(content)
      return if letters.blank?

      Result.new(letters: letters, source: "lira", text: text.to_s)
    end

    def self.blank_letters
      Array.new(Enem::ScoreScale::QUESTION_COUNT)
    end

    def self.letters_from_json(content)
      return if content.blank?

      json = content[/\{.*\}/m]
      parsed = JSON.parse(json.to_s)
      Enem::AnswerMap.from(parsed["answers"] || parsed["gabarito"] || parsed["letters"])
    rescue JSON::ParserError
      nil
    end
  end
end
