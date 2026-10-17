module Maestro
  class CommandInterpreter
    HELP = Lira::Scope.help_text

    def initialize(professor)
      @professor = professor
    end

    def reply(text)
      key = command_key(text)
      body =
        case key
        when :ajuda then HELP
        when :hoje then today_text
        when :status then status_text
        when :avisos then notices_text
        end
      return if body.blank?

      topic = { ajuda: :help, hoje: :today, status: :status, avisos: :notices }.fetch(key, :general)
      Lira::Scope.with_opening(body, professor: @professor, topic: topic)
    end

    private

    def command_key(text)
      normalized = Lessons::NameMatcher.normalize(text.to_s).strip
      return :ajuda if normalized.match?(/\A(ajuda|help|comandos)\z/)
      return :hoje if normalized.match?(/\A(hoje|briefing|resumo)\z/)
      return :status if normalized.match?(/\Astatus\z/)
      return :avisos if normalized.match?(/\Aavisos?\z/)

      nil
    end

    def today_text
      Lira::DailyBriefing.new(professor: @professor).command_text
    end

    def status_text
      wa = @professor.whatsapp_number.presence || "não vinculado"
      api = Lira.whatsapp_enabled? ? "API conectada" : "API ainda sem token no servidor"
      [
        "*Status do Maestro*",
        "Caderno neste computador: ativo.",
        "WhatsApp do professor: #{wa}.",
        "#{api}.",
        "Cérebro da conversa: #{Lira.brain_label}.",
        "Avisos não lidos: #{@professor.automation_notices.unread.count}."
      ].join("\n")
    end

    def notices_text
      notices = @professor.automation_notices.newest.limit(5)
      return "Nenhum aviso da automação ainda." if notices.empty?

      lines = ["*Últimos avisos*"]
      notices.each do |notice|
        mark = notice.unread? ? "novo" : "lido"
        lines << "- #{notice.title} (#{mark}): #{notice.body}"
      end
      lines.join("\n")
    end
  end
end
