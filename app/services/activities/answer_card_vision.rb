module Activities
  class AnswerCardVision
    Result = Struct.new(:name, :answers, :source, :bubbles, keyword_init: true) do
      def filled_count
        (answers || {}).values.count { |letter| Question::LETTERS.include?(letter) }
      end
    end

    def self.scan(path, question_count:)
      return unless Lira.llm_enabled?

      adapter = Lira::Brain.adapter
      return unless adapter.respond_to?(:analyze_file)

      content = adapter.analyze_file(
        path: path,
        prompt: prompt_for(question_count),
        system: "Você lê cartão-resposta de prova escolar. Não invente nome nem bolha. JSON puro."
      )
      parsed = parse_json(content)
      return if parsed.blank?

      Result.new(
        name: clean_name(parsed["name"] || parsed["nome"]),
        answers: letters_from(parsed["answers"] || parsed["gabarito"] || parsed["letters"], question_count),
        source: "lira",
        bubbles: bubbles_from(parsed["bubbles"] || parsed["bolhas"])
      )
    rescue StandardError => error
      Rails.logger.warn("[exam-vision] #{error.class}: #{error.message}")
      nil
    end

    def self.prompt_for(count)
      <<~PROMPT
        Este PDF ou foto é o CARTÃO-RESPOSTA. Itens Q.1 a Q.#{count} (algum número pode ser discursivo, sem bolha).
        Alternativas A–E (ou a–e) em colunas. Uma bolha pintada por linha objetiva.
        1) Leia o nome impresso ou manuscrito, se houver.
        2) Leia só as bolhas preenchidas.

        Responda só JSON:
        {"name":"nome do aluno ou null","answers":{"1":"A","2":"B"},"bubbles":{"1":{"A":[0.62,0.31],"B":[0.70,0.31]}}}
        Em bubbles, o centro de cada bolha visível em fração da largura e da altura (0 a 1).
        Omita questão sem bolha nítida.
      PROMPT
    end

    def self.letters_from(raw, count)
      mapped = {}
      case raw
      when Array
        raw.each_with_index do |value, index|
          number = index + 1
          next unless number.between?(1, count)

          letter = Enem::AnswerMap.letter(value)
          mapped[number.to_s] = letter if letter
        end
      when Hash
        raw.each do |key, value|
          number = key.to_s.to_i
          next unless number.between?(1, count)

          letter = Enem::AnswerMap.letter(value)
          mapped[number.to_s] = letter if letter
        end
      end
      mapped
    end

    def self.parse_json(content)
      return if content.blank?

      JSON.parse(content[/\{.*\}/m].to_s)
    rescue JSON::ParserError
      nil
    end

    def self.bubbles_from(raw)
      CardMark.normalize_bubbles(raw)
    end

    def self.clean_name(value)
      name = value.to_s.gsub(/\s+/, " ").strip
      return if name.blank?
      return if name.match?(/\A(null|nome completo|assinatura|aluno)\z/i)
      return if name.length < 3

      name
    end
  end
end
