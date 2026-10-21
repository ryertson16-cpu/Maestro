module Enem
  class CardVision
    Result = Struct.new(:name, :letters, :source, keyword_init: true) do
      def filled_count
        Array(letters).count { |letter| Question::LETTERS.include?(letter) }
      end
    end

    SYSTEM = "Você lê cartão-resposta de simulado ENEM. Não invente nome nem bolha. JSON puro.".freeze

    PROMPT = <<~PROMPT.freeze
      Este PDF/imagem é um CARTÃO-RESPOSTA de simulado ENEM (2º dia).
      1) Leia o nome manuscrito no campo "Nome completo" (e a assinatura só se o nome estiver ilegível).
      2) Leia as bolhas preenchidas. No cartão oficial do 2º dia as questões vão de 91 a 180
         (91–135 Ciências da Natureza, 136–180 Matemática). Isso são 90 itens.

      Responda só JSON:
      {"name":"nome do aluno ou null","answers":{"91":"A","92":"B"}}
      Use A, B, C, D ou E. Omita questão sem bolha nítida.
    PROMPT

    def self.scan(path)
      return unless Lira.llm_enabled?

      adapter = Lira::Brain.adapter
      return unless adapter.respond_to?(:analyze_file)

      content = adapter.analyze_file(path: path, prompt: PROMPT, system: SYSTEM)
      parsed = parse_json(content)
      return if parsed.blank?

      Result.new(
        name: clean_name(parsed["name"] || parsed["nome"]),
        letters: Enem::AnswerMap.from(parsed["answers"] || parsed["gabarito"] || parsed["letters"]),
        source: "lira"
      )
    rescue StandardError => error
      Rails.logger.warn("[enem-vision] #{error.class}: #{error.message}")
      nil
    end

    def self.parse_json(content)
      return if content.blank?

      JSON.parse(content[/\{.*\}/m].to_s)
    rescue JSON::ParserError
      nil
    end

    def self.clean_name(value)
      name = value.to_s.gsub(/\s+/, " ").strip
      return if name.blank?
      return if name.match?(/\A(null|nome completo|assinatura)\z/i)
      return if name.length < 5

      name
    end
  end
end
