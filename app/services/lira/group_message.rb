module Lira
  class GroupMessage
    MARKER = "Mensagem para colar no grupo".freeze
    MAX_NAMES = 20

    def self.reply(toolkit, text)
      new(toolkit, text).reply
    end

    def self.delivery_text(facts)
      names = Array(facts[:students]).map { |row| row[:name] }
      listed = names.first(MAX_NAMES)
      extra = names.size - listed.size
      status = facts[:status_filter]
      due = facts[:due_date].respond_to?(:strftime) ? facts[:due_date].strftime("%d/%m/%Y") : facts[:due_date]

      case status
      when :not_delivered
        <<~TEXT.strip
          📝 *#{facts[:activity]}* — turma #{facts[:classroom]}

          Olá, turma! 👋
          Estou enviando o relatório desta atividade. Conferiram aí?

          ⚠️ *Atenção:* ainda sem entrega neste lançamento:
          #{bullet_list(listed, extra)}

          Prazo de referência: #{due}. Qualquer dúvida, me chamem.
        TEXT
      when :delivered_late
        <<~TEXT.strip
          ⏰ *#{facts[:activity]}* — turma #{facts[:classroom]}

          Olá, turma! 👋
          Segue o relatório. Quem entregou depois do limite aparece como entrega com atraso:

          #{bullet_list(listed, extra)}

          Vale regularizar o que ainda estiver em aberto. 💪
        TEXT
      else
        counts = facts[:counts] || {}
        <<~TEXT.strip
          📝 *#{facts[:activity]}* — turma #{facts[:classroom]}

          Olá, turma! 👋
          Estou enviando o relatório da atividade. Dá uma olhada na sua situação, por favor.

          ✅ Entregues: #{counts[:delivered].to_i}
          ⏰ Com atraso: #{counts[:delivered_late].to_i}
          📌 Em andamento: #{counts[:in_progress].to_i}
          ⚠️ Sem entrega: #{counts[:not_delivered].to_i}

          Quem estiver pendente, regulariza assim que puder. Qualquer dúvida, me chamem. ✨
        TEXT
      end
    end

    def self.bullet_list(names, extra)
      return "Ninguém neste recorte." if names.empty?

      lines = names.map { |name| "• #{name}" }
      lines << "• e mais #{extra}" if extra.positive?
      lines.join("\n")
    end

    def initialize(toolkit, text)
      @toolkit = toolkit
      @text = text.to_s
    end

    def reply
      classrooms = @toolkit.matching_classrooms(@text)
      if classrooms.size > 1
        return Lira::Scope.format_ambiguous_classrooms(classrooms, professor: @toolkit.professor)
      end
      if classrooms.empty?
        return Lira::Scope.with_opening(
          "#{Lira::Scope.icon(:ask)} Diga a turma do grupo (ex.: 3ª O) para eu montar o recado com os dados certos.",
          professor: @toolkit.professor,
          topic: :whatsapp
        )
      end

      classroom = classrooms.first
      body = delivery_alert? ? delivery_draft(classroom) : generic_draft(classroom)
      return body if body.start_with?("Tudo bem,")

      wrap(body)
    end

    private

    def wrap(body)
      Lira::Scope.with_opening(
        "#{body}\n\n#{Lira::Scope.icon(:ok)} Eu não envio no WhatsApp. Copie e cole no grupo.",
        professor: @toolkit.professor,
        topic: :whatsapp
      )
    end

    def delivery_alert?
      @text.match?(/relat[oó]rio|n[aã]o entreg|sem entrega|atraso|entreg|atividade|pendenc|andament/i)
    end

    def delivery_draft(classroom)
      facts = @toolkit.activity_delivery_status(
        classroom: classroom.name,
        activity: quoted_title,
        status: status_hint
      )
      return Lira::Scope.format_result(facts, professor: @toolkit.professor, topic: :ask) if facts[:error].present?

      draft_from(facts)
    end

    def generic_draft(classroom)
      intent = group_intent
      <<~TEXT.strip
        📋 *#{MARKER}*

        📣 *Turma #{classroom.name}*

        Olá, turma! 👋
        #{intent}

        Qualquer dúvida, me chamem. ✨
      TEXT
    end

    def group_intent
      cleaned = @text.to_s.dup
      cleaned.gsub!(
        /mensagem|comunicado|recado|whatsapp|colar no grupo|grupo da turma|grupo dos alunos|crie|cria|monte|escreva|para (o|a) (grupo|turma)/i,
        " "
      )
      cleaned.gsub!(/"[^"]+"|'[^']+'/, " ")
      cleaned.gsub!(/\b\d+\s*[ªºo]?\s*[a-z]\b/i, " ")
      cleaned = cleaned.gsub(/[.,:;]+/, " ").squeeze(" ").strip
      cleaned.sub!(/\A(da|do|de|a|o|um|uma)\s+/i, "")
      return "Passando um recado importante. Fiquem atentos, por favor." if cleaned.length < 8

      cleaned[0] = cleaned[0].upcase
      cleaned.end_with?(".", "!", "?") ? cleaned : "#{cleaned}."
    end

    def quoted_title
      @text[/"([^"]+)"/, 1] || @text[/'([^']+)'/, 1]
    end

    def status_hint
      return "não entregou" if @text.match?(/n[aã]o entreg|sem entrega|pendenc/i)
      return "atraso" if @text.match?(/atraso/i)
      return "entregue" if @text.match?(/quem (já )?entreg/i)
      return "em andamento" if @text.match?(/andament/i)

      nil
    end

    def draft_from(facts)
      "📋 *#{MARKER}*\n\n#{self.class.delivery_text(facts)}"
    end
  end
end
