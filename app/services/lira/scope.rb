# frozen_string_literal: true

module Lira
  # Manual da Lira (Maestro): persona, formato, emojis e proibições.
  # O prompt da IA e as respostas locais saem daqui para a voz não divergir.
  module Scope
    ICONS = {
      classroom: "📋",
      lesson: "📚",
      attendance: "✅",
      late: "⏰",
      absent: "❌",
      activity: "📝",
      grade: "📊",
      alert: "⚠️",
      siage: "📤",
      project: "🎯",
      ok: "✨",
      ask: "❓"
    }.freeze

    module_function

    def icon(key)
      ICONS.fetch(key)
    end

    def late_rule
      "Atraso não é falta."
    end

    TOPIC_SENTENCES = {
      attendance: "Segue a frequência.",
      grades: "Seguem as notas.",
      monitoring: "Olha os alertas do monitoramento.",
      lessons: "Seguem as aulas.",
      projects: "Seguem os projetos — eles não entram no SIAGE.",
      classrooms: "Seguem as turmas.",
      students: "Seguem os alunos que encontrei.",
      student: "Segue o que encontrei sobre o aluno.",
      help: "Posso te orientar nos comandos do caderno.",
      today: "Olha o que tem para hoje.",
      greeting: "Estou aqui com o caderno.",
      status: "Segue o status do Maestro neste computador.",
      notices: "Seguem os avisos.",
      whatsapp: "Segue a mensagem para colar no grupo.",
      siage: "Segue o que encontrei no SIAGE.",
      ask: "Preciso de um detalhe para consultar o caderno.",
      unknown: "Diga a turma ou o aluno que eu consulto o caderno.",
      error: "Não consegui fechar essa consulta.",
      blank: "Pode escrever a pergunta que eu consulto o caderno.",
      general: "Segue o que encontrei no caderno."
    }.freeze

    def address(professor)
      return "professor" if professor.blank?

      [professor.courtesy_role, professor.greeting_name].compact.join(" ")
    end

    def topic_sentence(topic)
      TOPIC_SENTENCES.fetch(topic.to_sym, TOPIC_SENTENCES[:general])
    end

    def topic_for(text)
      normalized = Lessons::NameMatcher.normalize(text.to_s).strip
      return :blank if normalized.blank?
      return :help if normalized.match?(/\A(ajuda|help|comandos)\z/)
      return :today if normalized.match?(/\A(hoje|briefing|resumo)\z/)
      return :status if normalized.match?(/\Astatus\z/)
      return :notices if normalized.match?(/\Aavisos?\z/)
      return :whatsapp if text.match?(/whatsapp|mensagem|comunicado|recado|colar no grupo|grupo da turma|grupo dos alunos/i)
      return :greeting if normalized.match?(/\A(oi|ola|bom dia|boa tarde|boa noite|e ai|hey|lira|maestro)\b/)
      return :monitoring if text.match?(/monitor|alerta|pendenc|risco|cuidado|aten(c|ç)ao/i)
      return :projects if text.match?(/projeto|nota\s*10|portf[oó]lio/i)
      return :grades if text.match?(/nota|m[eé]dia|bimestre|recupera|aprovad/i)
      return :attendance if text.match?(/frequ|falt|presen|atraso|chamada/i)
      return :siage if text.match?(/siage|planilha|livro.?raz/i)
      return :lessons if text.match?(/aula|di[aá]rio|conte[uú]do|tema/i)
      return :classrooms if text.match?(/turma/i)
      return :students if text.match?(/aluno/i)

      :general
    end

    def opening_line(professor: nil, topic: :general)
      "Tudo bem, #{address(professor)}. #{topic_sentence(topic)}"
    end

    def with_opening(body, professor:, topic: :general)
      text = body.to_s.strip
      lead = opening_line(professor: professor, topic: topic)
      return lead if text.blank?
      return text if text.start_with?("Tudo bem,")

      "#{lead}\n\n#{text}"
    end

    def greeting
      <<~TEXT.squish
        Olá! Eu sou o #{Lira::NAME}, o caderno digital do professor.
        Posso consultar turmas, alunos, frequência, notas, atividades,
        projetos pedagógicos e o monitoramento — sempre com os dados da sua conta.
        Envie hoje, avisos ou o nome de um aluno. #{late_rule}
      TEXT
    end

    def help_text
      <<~TEXT.strip
        Eu sou o #{Lira::NAME}. Consulto só o seu caderno.

        #{icon(:lesson)} *hoje* — aulas, chamada e pendências de hoje
        #{icon(:ok)} *status* — se o Maestro neste PC está ativo
        #{icon(:alert)} *avisos* — últimos recados da automação
        #{icon(:ask)} *ajuda* — esta lista
        #{icon(:activity)} mensagem para o grupo — recado de WhatsApp para copiar (não envio)

        Lembrete: “me lembra da reunião amanhã às 19h”. Avisa no sino com o caderno aberto.

        Também pode perguntar, por exemplo: frequência da Maria na 2ª A.
        #{late_rule} Sem o Maestro aberto neste computador, eu não consulto a turma.
        #{icon(:project)} Projetos não entram no SIAGE.
      TEXT
    end

    def system_prompt(professor: nil)
      addressed = address(professor)

      <<~PROMPT
        Você é o #{Lira::NAME}, o caderno digital e assistente pedagógico do professor.

        ## Persona
        Fale em português do Brasil, cordial, claro e curto.
        A pessoa com quem você fala é #{addressed}.
        Você consulta e explica. Não altera cadastro, nota, frequência nem SIAGE.
        Responda só com dados do professor que está conversando, obtidos pelas ferramentas.
        Não invente aluno, nota, falta, turma, aula ou projeto.
        #{late_rule} Atraso entra como presente no SIAGE.
        Projetos pedagógicos (turma, Professor Nota 10, Escola Nota 10) não são notas nem frequência do SIAGE.
        Não preencha REC GLOBAL. REC só existe por atividade, no lançamento.
        Quando o professor citar aluno e turma juntos, passe os dois para a ferramenta. 2ª H e 2ª I são turmas diferentes.
        Se houver dois alunos com o mesmo nome, não escolha no chute: liste nome e turma e pergunte qual é.
        Se faltar turma ou aluno, pergunte. Quando a pergunta for ampla, resuma e ofereça aprofundar.

        ## Formato
        1. Sempre comece a resposta com exatamente: “Tudo bem, #{addressed}. ” e uma frase do tema (frequência, notas, alertas, aulas, SIAGE, projetos, hoje, ajuda).
           Exemplos: “Tudo bem, #{addressed}. Segue a frequência.” / “Tudo bem, #{addressed}. Olha os alertas do monitoramento.”
        2. Depois, lista curta, um fato por linha, com o emoji do tema.
        3. Se couber, uma pergunta: “Quer que eu aprofunde a 2ª F?”
        Sem parágrafo de coach, sem enrolação, sem emoji em todo número.
        Não cumprimente de outro jeito (nada de Olá/Oi/Claro no lugar dessa abertura).

        ## Emojis (rótulo, não enfeite)
        #{icon(:classroom)} turma
        #{icon(:lesson)} aula / diário
        #{icon(:attendance)} presença
        #{icon(:late)} atraso (não é falta)
        #{icon(:absent)} falta
        #{icon(:activity)} atividade
        #{icon(:grade)} nota / média
        #{icon(:alert)} alerta / cuidado
        #{icon(:siage)} SIAGE
        #{icon(:project)} projeto (nunca como nota SIAGE)
        #{icon(:ok)} em dia
        #{icon(:ask)} pergunta ao professor

        ## WhatsApp e /lira
        O mesmo texto nos dois canais. Negrito só em comandos (*hoje*). Não use HTML.

        ## Recado para o grupo dos alunos
        Quando o professor pedir mensagem, comunicado, alerta ou texto para colar no WhatsApp da turma:
        1. Consulte o caderno com as ferramentas (atividade, situação de entrega, notas, frequência). Não invente aluno.
        2. Fale primeiro com o professor, na abertura obrigatória.
        3. Depois escreva um bloco pronto para colar, começando exatamente com: 📋 *Mensagem para colar no grupo*
        4. No bloco: tom de professor no grupo, emojis, frases curtas, *negrito* do WhatsApp. Sem HTML.
        5. Se pedirem alerta de quem está em certa situação no relatório (não entregou, atraso etc.), liste só esses nomes, com os dados da ferramenta.
        6. Nunca envie a mensagem. Não use a API do WhatsApp. O professor copia e cola.
        7. Sem CPF, telefone, nota individual detalhada demais no grupo, salvo se o professor pedir explicitamente o nome naquela situação.
      PROMPT
    end

    def fallback(professor: nil)
      with_opening(
        "#{icon(:ask)} Posso ajudar com turmas, alunos, frequência, notas, aulas, projetos e monitoramento. #{late_rule}",
        professor: professor,
        topic: :unknown
      )
    end

    def offer_deeper(student: nil, classroom: nil)
      context = [student&.name, classroom&.name].compact
      return if context.empty?

      "#{icon(:ask)} Quer que eu aprofunde #{context.to_sentence}?"
    end

    def format_result(result, student: nil, classroom: nil, professor: nil, topic: nil)
      if result.is_a?(Hash) && result[:error].present?
        lines = ["#{icon(:ask)} #{result[:error]}"]
        lines.concat(format_candidates(result[:candidates])) if result[:candidates].present?
        return with_opening(lines.join("\n"), professor: professor, topic: :ask)
      end

      resolved_topic = topic.presence || topic_from_result(result)
      lines = []

      case result
      when Array
        if result.first.is_a?(Hash) && result.first.key?(:alerts)
          lines.concat(format_monitoring_list(result))
        elsif result.first.is_a?(Hash) && result.first.key?(:theme)
          lines.concat(format_lessons(result))
        elsif result.first.is_a?(Hash) && result.first.key?(:kind_label)
          lines.concat(format_projects(result))
        else
          lines.concat(format_classrooms(result))
        end
      when Hash
        if result[:students].is_a?(Array) && result[:bimester]
          lines.concat(format_grades(result))
        elsif result[:students].is_a?(Array) && result[:month]
          lines.concat(format_attendance(result))
        elsif result[:summary]
          lines.concat(format_monitoring_classroom(result))
        elsif result.key?(:registration)
          lines.concat(format_student(result))
        elsif result[:student_count]
          lines.concat(format_classroom(result))
        elsif result[:students]
          lines.concat(format_student_search(result))
        else
          lines << result.to_json
        end
      else
        lines << result.to_s
      end

      deeper = offer_deeper(student: student, classroom: classroom)
      lines << deeper if deeper
      with_opening(lines.join("\n"), professor: professor, topic: resolved_topic)
    end

    def topic_from_result(result)
      case result
      when Array
        return :monitoring if result.first.is_a?(Hash) && result.first.key?(:alerts)
        return :lessons if result.first.is_a?(Hash) && result.first.key?(:theme)
        return :projects if result.first.is_a?(Hash) && result.first.key?(:kind_label)

        :classrooms
      when Hash
        return :grades if result[:students].is_a?(Array) && result[:bimester]
        return :attendance if result[:students].is_a?(Array) && result[:month]
        return :monitoring if result[:summary]
        return :student if result.key?(:registration)
        return :classrooms if result[:student_count]
        return :students if result[:students]
      end

      :general
    end

    def format_classrooms(rows)
      return ["#{icon(:classroom)} Você ainda não tem turmas cadastradas."] if rows.blank?

      ["#{icon(:classroom)} Turmas:"] + rows.map do |row|
        "#{icon(:classroom)} #{row[:name]} (#{row[:year]}, #{row[:shift]}): #{row[:students]} aluno(s)"
      end
    end

    def format_student_search(result)
      return ["#{icon(:ask)} Não encontrei alunos com esse nome."] if result[:students].blank?

      ["#{icon(:classroom)} Alunos:"] + result[:students].map do |row|
        rooms = Array(row[:classrooms]).presence&.join(", ") || "sem turma"
        "#{icon(:classroom)} #{row[:name]} (#{rooms})"
      end
    end

    def format_student(result)
      lines = ["#{icon(:classroom)} #{result[:name]}"]
      lines << "Matrícula: #{result[:registration]}" if result[:registration].present?
      Array(result[:classrooms]).each do |room|
        lines << "#{icon(:attendance)} Turma #{room[:classroom]}: frequência do mês #{room[:attendance_month] || 'sem lançamento'}%."
        if room[:pending_activities].present?
          lines << "#{icon(:activity)} Pendências: #{room[:pending_activities].join(', ')}."
        end
      end
      lines
    end

    def format_classroom(result)
      [
        "#{icon(:classroom)} #{result[:name]} — #{result[:student_count]} aluno(s), #{result[:lessons_this_month]} aula(s) neste mês.",
        "#{icon(:classroom)} Alunos: #{Array(result[:students]).first(15).join(', ')}.",
        "#{icon(:alert)} Alertas do mês: #{result.dig(:alerts, :total).to_i}."
      ]
    end

    def format_attendance(result)
      lines = ["#{icon(:attendance)} Frequência de #{result[:month]}#{result[:classroom] ? " na #{result[:classroom]}" : ''}."]
      Array(result[:students]).first(15).each do |row|
        lines << "#{icon(:attendance)} #{row[:name]}: #{row[:percentage]}% (#{row[:present]} presentes, #{icon(:absent)} #{row[:absent]} faltas, #{icon(:late)} #{row[:late]} atrasos)"
      end
      lines << late_rule
      lines
    end

    def format_grades(result)
      lines = ["#{icon(:grade)} Notas do #{result[:bimester]}º bimestre na #{result[:classroom]}."]
      Array(result[:students]).first(15).each do |row|
        score = row[:final_score] || "sem média"
        lines << "#{icon(:grade)} #{row[:name]}: #{score} (#{row[:situation]})"
      end
      lines
    end

    def format_monitoring_classroom(result)
      [
        "#{icon(:alert)} Monitoramento de #{result[:month]} na #{result[:classroom]}: #{result.dig(:summary, :total).to_i} alerta(s).",
        *Array(result[:students]).first(10).map { |row| "#{icon(:alert)} #{row[:name]} (#{row[:severity]})" }
      ]
    end

    def format_monitoring_list(rows)
      return ["#{icon(:ok)} Nenhum alerta neste mês. Bom trabalho."] if rows.blank?

      ["#{icon(:alert)} Monitoramento por turma:"] + rows.map do |row|
        "#{icon(:alert)} #{row[:classroom]}: #{row[:alerts]} alerta(s). #{Array(row[:students]).join(', ')}"
      end
    end

    def format_lessons(rows)
      return ["#{icon(:lesson)} Não há aulas nessa janela."] if rows.blank?

      ["#{icon(:lesson)} Aulas:"] + rows.map do |row|
        extra = row[:activity].present? ? " — #{row[:activity]}" : ""
        "#{icon(:lesson)} #{row[:date]} · #{row[:classroom]} · #{row[:theme]}#{extra}"
      end
    end

    def format_projects(rows)
      return ["#{icon(:project)} Você ainda não tem projetos cadastrados."] if rows.blank?

      ["#{icon(:project)} Projetos (não entram no SIAGE):"] + rows.map do |row|
        rooms = Array(row[:classrooms]).presence&.join(", ")
        overdue = Array(row[:overdue])
        extra = overdue.any? ? " · atrasado: #{overdue.join(', ')}" : ""
        suffix = rooms.present? ? " · #{rooms}" : ""
        "#{icon(:project)} #{row[:title]} (#{row[:kind_label]}, #{row[:status]}, #{row[:progress]}%)#{suffix}#{extra}"
      end
    end

    def format_candidates(rows)
      Array(rows).map do |row|
        rooms = Array(row[:classrooms]).presence&.join(", ") || "sem turma"
        extra = row[:registration].present? ? " · #{row[:registration]}" : ""
        "#{icon(:classroom)} #{row[:name]} (#{rooms})#{extra}"
      end
    end

    def format_ambiguous_students(rows, professor: nil)
      lines = ["#{icon(:ask)} Encontrei mais de um aluno com esse nome. Qual turma?"]
      lines.concat(format_candidates(rows))
      with_opening(lines.join("\n"), professor: professor, topic: :ask)
    end

    def format_ambiguous_classrooms(classrooms, professor: nil)
      names = classrooms.map(&:name).join(", ")
      with_opening(
        "#{icon(:ask)} Encontrei mais de uma turma. Qual delas: #{names}?",
        professor: professor,
        topic: :ask
      )
    end

    def format_wake(professor:, weekday_label:, date_label:, day_lines:)
      with_opening(
        [
          "#{icon(:lesson)} Hoje é #{weekday_label}, #{date_label}.",
          *day_lines,
          "",
          "#{icon(:ask)} Pode me pedir o resumo do dia, a chamada, o SIAGE, os alertas ou o nome de um aluno. #{late_rule}"
        ].join("\n"),
        professor: professor,
        topic: :today
      )
    end

    def format_today_command(professor:, weekday_label:, date_label:, day_lines:)
      with_opening(
        ["#{icon(:lesson)} Hoje · #{weekday_label} (#{date_label})", *day_lines].join("\n"),
        professor: professor,
        topic: :today
      )
    end
  end
end
