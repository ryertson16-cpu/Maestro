module ApplicationHelper
  def maestro_toasts
    toasts = []
    recap = maestro_recap_toast

    if recap
      toasts << recap
    elsif notice.present?
      toasts << { kind: "success", title: "Sucesso", message: notice }
    end

    if alert.present?
      toasts << { kind: "error", title: "Erro", message: alert }
    end

    warning = flash[:warning].presence || flash[:attention].presence
    if warning.present?
      toasts << { kind: "attention", title: "Atenção", message: warning }
    end

    toasts.concat(Array(@login_pending_toasts))
    toasts.each { |toast| decorate_maestro_toast!(toast) }
    toasts
  end

  def maestro_recap_toast
    raw = flash[:maestro_recap]
    return if raw.blank?

    payload = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    payload = payload.deep_stringify_keys
    return if payload["message"].blank? && Array(payload["lines"]).blank?

    payload.merge("kind" => "maestro")
  end

  def decorate_maestro_toast!(toast)
    icon_name = toast[:icon] || toast["icon"]
    if icon_name.to_s == "monitoring"
      toast[:icon_url] ||= toast["icon_url"].presence || asset_path("monitoring-icon.png")
    end
    if icon_name.to_s.in?(%w[bell avisos notices])
      toast[:icon_url] ||= toast["icon_url"].presence || asset_path("notices-icon.png")
    end

    kind = toast[:kind] || toast["kind"]
    return unless kind.to_s == "maestro"

    toast[:icon_url] ||= toast["icon_url"].presence || asset_path("maestro-assistant.png")
  end

  def maestro_logo_tag(variant = :header)
    css =
      case variant.to_sym
      when :auth then "auth-logo"
      else "brand-logo"
      end

    image_tag "maestro-logo.png",
              class: css,
              alt: "Maestro, o caderno digital do professor"
  end

  def maestro_assistant_mark(size: :md, html_class: nil)
    classes = [
      "maestro-assistant-mark",
      "maestro-assistant-mark-#{size}",
      html_class
    ].compact.join(" ")

    image_tag "maestro-assistant.png",
              class: classes,
              alt: "Maestro"
  end

  def maestro_nav_link(label, path, section)
    classes = ["nav-link"]
    classes << "is-active" if maestro_nav_section == section

    link_to label, path, class: classes.join(" ")
  end

  def maestro_nav_section
    case controller_name
    when "attendance_records", "siage_exports", "siage_ledgers"
      :diario
    when "lessons", "school_calendars", "lesson_plan_templates", "timetables"
      :diario
    when "classrooms", "students", "enrollments", "projects", "project_stages", "courses", "school_courses"
      :turmas
    when "grades", "activities", "bimester_closings", "questions", "corrections", "activity_questions", "public_corrections", "online_activities"
      :atividades
    when "monitoring", "council_notes"
      :monitoramento
    when "profiles", "settings", "schools"
      nil
    when "grade_levels"
      if action_name.in?(%w[index exam_result save_submissions activity_report activity_notice])
        :atividades
      else
        :turmas
      end
    end
  end

  def maestro_nav_path(helper, classroom = remembered_classroom, **params)
    if classroom
      public_send(helper, **params.merge(classroom_id: classroom.id))
    else
      public_send(helper, **params)
    end
  end

  def maestro_nav_groups
    classroom = remembered_classroom

    [
      {
        key: :diario,
        label: "Diário",
        icon: :diary,
        href: maestro_nav_path(:attendance_records_path, classroom),
        items: [
          { label: "Calendário", href: maestro_nav_path(:school_calendar_path, classroom), hint: "Dias letivos e gerar aula" },
          { label: "Meu horário", href: timetable_path, hint: "Grade da semana a partir do PDF da escola" },
          { label: "Aulas", href: maestro_nav_path(:lessons_path, classroom), hint: "Aulas já registradas" },
          { label: "Planos", href: lesson_plan_templates_path, hint: "Modelos de plano de aula" },
          { label: "Abrir SIAGE", href: siage_open_path, hint: "Extensão #{Siage::EXTENSION_VERSION}: login, Frequência e Avaliações", emphasis: true },
          { label: "Envios SIAGE", href: siage_ledger_path, hint: "Livro-razão de todas as turmas", emphasis: true }
        ]
      },
      {
        key: :turmas,
        label: "Turmas",
        icon: :classrooms,
        href: classrooms_path,
        items: [
          { label: "Alunos", href: students_path, hint: "Fichas, frequência e matrícula na turma" },
          { label: "Projetos", href: projects_path, hint: "Professor e Escola Nota 10" }
        ]
      },
      {
        key: :atividades,
        label: "Atividades",
        icon: :activities,
        href: maestro_nav_path(:grade_levels_path, classroom),
        items: [
          { label: "Banco de questões", href: questions_path, hint: "Questões próprias para montar a atividade" },
          { label: "Corrigir por QR", href: corrections_path, hint: "QR no computador, câmera no celular" },
          { label: "Atividade online", href: new_online_activity_path, hint: "Planilha do Forms: aula, nota e presença" },
          { label: "Simulado ENEM", href: enem_simulados_path, hint: "Gabarito oficial, cartões e escala de acertos" }
        ]
      },
      {
        key: :monitoramento,
        label: "Monitoramento",
        icon: :monitoring,
        href: maestro_nav_path(:monitoring_path, classroom),
        items: [
          ({
            label: "Conselho",
            href: council_notes_path(classroom_id: classroom.id),
            hint: "Pareceres do bimestre"
          } if classroom)
        ].compact
      }
    ]
  end

  def siage_pending_nav_count
    return 0 unless professor_signed_in?

    @siage_pending_nav_count ||= Siage::Ledger.new(professor: current_professor).summary[:pending].to_i
  end

  def maestro_bottom_nav_items
    items = maestro_nav_groups.map do |group|
      {
        key: group[:key],
        label: group[:label],
        href: group[:href],
        icon: group[:icon]
      }
    end

    items << {
      key: :siage,
      label: "SIAGE",
      href: siage_ledger_path,
      icon: :siage,
      badge: siage_pending_nav_count
    }

    items
  end

  def maestro_bottom_nav_section
    return :siage if controller_name.in?(%w[siage_ledgers siage_exports])

    maestro_nav_section
  end

  def maestro_switchable_classrooms
    return Classroom.none unless professor_signed_in?

    current_professor.classrooms.order(active: :desc, name: :asc)
  end

  def maestro_classroom_switch_allow_all?
    return true if controller_name.in?(%w[siage_ledgers students projects lessons]) && action_name.in?(%w[index])
    return true if controller_name == "siage_ledgers"
    return true if controller_name == "dashboard"
    return true if controller_name == "classrooms" && action_name == "index"

    false
  end

  def maestro_classroom_switch_selected_id
    if controller_name == "siage_ledgers"
      return params[:classroom_id].presence || @classroom&.id
    end

    if maestro_classroom_switch_allow_all? &&
       controller_name.in?(%w[students projects lessons classrooms dashboard]) &&
       (action_name == "index" || controller_name == "dashboard") &&
       params[:classroom_id].blank?
      return nil
    end

    @classroom&.id || @selected_classroom&.id || remembered_classroom&.id
  end

  def maestro_classroom_switch_path(classroom_id = nil)
    id = classroom_id.presence

    case controller_name
    when "attendance_records"
      attendance_records_path({ classroom_id: id, attendance_date: params[:attendance_date] }.compact)
    when "grade_levels"
      grade_levels_path({ classroom_id: id, bimester: params[:bimester], kind: params[:kind] }.compact)
    when "grades"
      id.present? ? grades_path({ classroom_id: id, bimester: params[:bimester] }.compact) : grade_levels_path
    when "monitoring"
      monitoring_path({ classroom_id: id, month: params[:month], filter: params[:filter] }.compact)
    when "council_notes"
      id.present? ? council_notes_path({ classroom_id: id, bimester: params[:bimester] }.compact) : classrooms_path
    when "bimester_closings"
      id.present? ? bimester_closing_path({ classroom_id: id, bimester: params[:bimester] }.compact) : classrooms_path
    when "school_calendars"
      school_calendar_path({ classroom_id: id, year: params[:year], day: params[:day] }.compact)
    when "lessons"
      if action_name == "new"
        new_lesson_path({ classroom_id: id, lesson_date: params[:lesson_date] }.compact)
      else
        lessons_path({ classroom_id: id }.compact)
      end
    when "classrooms"
      if id.present? && action_name.in?(%w[show edit])
        action_name == "edit" ? edit_classroom_path(id) : classroom_path(id)
      elsif id.present?
        classroom_path(id)
      else
        classrooms_path
      end
    when "siage_ledgers", "siage_exports"
      siage_ledger_path({ classroom_id: id }.compact)
    when "students"
      students_path({ classroom_id: id, month: params[:month], search: params[:search] }.compact)
    when "projects"
      projects_path({ classroom_id: id, kind: params[:kind], status: params[:status] }.compact)
    when "enrollments"
      if action_name == "bulk_new" && id.present?
        bulk_new_enrollments_path(classroom_id: id)
      else
        enrollments_path
      end
    else
      id.present? ? classroom_path(id) : classrooms_path
    end
  end

  def maestro_classroom_switch_all_path
    maestro_classroom_switch_path(nil)
  end

  def maestro_classroom_switch_all_label
    if controller_name.in?(%w[siage_ledgers siage_exports])
      "Todas · SIAGE"
    else
      "Todas"
    end
  end

  def maestro_command_groups
    classrooms = command_palette_classrooms

    groups = [
      {
        title: "Sugestões",
        items: [
          command_item("Início", root_path, :cards, "Painel inicial", "home dashboard inicio painel"),
          command_item("Diário", maestro_nav_path(:attendance_records_path), :diary, "Aula, chamada e Frequência", "frequencia chamada siage"),
          command_item("Abrir SIAGE", siage_open_path, :siage, "Login, Frequência e Avaliações", "siage abrir portal cpf senha"),
          command_item("Envios SIAGE", siage_ledger_path, :siage, "Livro-razão da extensão #{Siage::EXTENSION_VERSION}", "siage livro razao exportar"),
          command_item("Ajuda SIAGE", siage_help_path, :siage, "Como usar a extensão #{Siage::EXTENSION_VERSION}", "siage json extensao aula ajuda"),
          command_item("Meu horário", timetable_path, :calendar, "Grade da semana", "horario pdf quadro aula"),
          command_item("Calendário", school_calendar_path, :calendar, "Dias letivos", "feriado aula"),
          command_item("Turmas", classrooms_path, :classrooms, "Lista de turmas", "turma"),
          command_item("Alunos", students_path, :students, "Fichas", "aluno"),
          command_item("Matrículas", enrollments_path, :people, "Vínculo de aluno e turma", "matricula"),
          command_item("Atividades", maestro_nav_path(:grade_levels_path), :activities, "Entregas e notas", "nota lista exercicio"),
          command_item("Banco de questões", questions_path, :clipboard, "Montar provas com o banco próprio", "questao objetiva discursiva banco"),
          command_item("Atividade online", new_online_activity_path, :activities, "Planilha do Google Forms", "forms planilha questionario online nota presenca"),
          command_item("Corrigir por QR", corrections_path, :check, "QR no PC, correção no celular", "qrcode correcao gabarito prova celular"),
          command_item("Projetos", projects_path, :projects, "Professor e Escola Nota 10", "projeto"),
          command_item("Monitoramento", monitoring_path, :monitoring, "Alertas e conselho", "alerta pendencia"),
          command_item("Disciplinas", courses_path, :courses, "Componentes e níveis", "disciplina curso"),
          {
            label: "Maestro",
            hint: "Lembrete rápido, sem abrir o chat",
            href: nil,
            action: "maestro-quick",
            icon: :assistant,
            search: "maestro lembrete conversar assistente lira ia"
          },
          command_item("Conversar", lira_path, :assistant, "Conversa completa", "assistente whatsapp ia lira maestro conversar historico"),
          command_item("Avisos", automation_notices_path, :bell, "Automações do caderno", "automacao sino alerta chamada")
        ]
      }
    ]

    if classrooms.any?
      groups << {
        title: "Turmas",
        items: classrooms.flat_map do |classroom|
          [
            command_item(
              "Turma · #{classroom.name}",
              classroom_path(classroom),
              :classrooms,
              "Hub da turma",
              "turma #{classroom.name}"
            ),
            command_item(
              "Diário · #{classroom.name}",
              attendance_records_path(classroom_id: classroom.id),
              :diary,
              "Chamada desta turma",
              "frequencia chamada #{classroom.name}"
            ),
            command_item(
              "Atividades · #{classroom.name}",
              grade_levels_path(classroom_id: classroom.id),
              :activities,
              "Notas desta turma",
              classroom.name
            )
          ]
        end
      }
    end

    groups << {
      title: "Atalhos",
      items: [
        command_item("Registrar aula", new_lesson_path, :activities, "Nova aula; a atividade é opcional", "atividade lista exercicio prova aula"),
        command_item("Nova turma", new_classroom_path, :classrooms, "Cadastrar turma", "criar turma"),
        command_item("Nova questão", new_question_path, :clipboard, "Guardar no banco próprio", "questao objetiva banco")
      ]
    }

    groups << {
      title: "Configurações",
      items: [
        command_item("Configurações", settings_path, :sliders, "Conta e preferências", "perfil conta"),
        command_item("Assinatura", assinatura_path, :check, "Mensalidade do Maestro", "plano pix pagar assinatura"),
        command_item("Automações", settings_path(anchor: "automacoes"), :bell, "Avisos neste PC", "agente chamada siage backup"),
        command_item("Perfil", edit_profile_path, :people, "Nome, foto, CPF, senha SIAGE e WhatsApp", "foto whatsapp cpf senha siage"),
        command_item("Escola", edit_school_path, :pin, "Nome, GRE e brasão", "brasao gre regional timbrado"),
        {
          label: "Alternar modo dia/noite",
          hint: "Tema da tela",
          href: nil,
          action: "theme",
          icon: :sliders,
          search: "tema night modo noturno dia claro escuro"
        }
      ]
    }

    groups
  end

  def enrollment_caderno_tag(enrollment)
    return if enrollment.blank?

    label = enrollment.caderno_tag
    return if label.blank?

    tag.span label, class: "caderno-tag"
  end

  private

  def command_item(label, href, icon, hint, extra_search = "")
    {
      label: label,
      hint: hint,
      href: href,
      action: nil,
      icon: icon,
      search: [label, hint, extra_search].join(" ")
    }
  end

  def command_palette_classrooms
    current = remembered_classroom
    rooms = current_professor.classrooms.order(:name).limit(12).to_a
    rooms.unshift(current) if current && rooms.none? { |room| room.id == current.id }
    rooms.uniq { |room| room.id }.sort_by { |room| room.id == current&.id ? 0 : 1 }
  end
end
