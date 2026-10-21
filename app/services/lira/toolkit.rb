module Lira
  class Toolkit
    STATUS_LABELS = {
      "present" => "presente",
      "absent" => "faltou",
      "justified" => "falta justificada",
      "late" => "atraso"
    }.freeze

    SITUATION_LABELS = {
      approved: "aprovado",
      recovery: "em recuperação",
      without_grades: "sem nota"
    }.freeze

    def initialize(professor)
      @professor = professor
    end

    attr_reader :professor

    def definitions
      [
        tool("list_classrooms", "Lista as turmas do professor com quantidade de alunos."),
        tool(
          "search_students",
          "Busca alunos pelo nome ou matrícula. Passe a turma quando o professor citar a turma, para não misturar homônimos.",
          {
            query: { type: "string", description: "Nome ou matrícula" },
            classroom: { type: "string", description: "Turma, se o professor informou" }
          },
          %w[query]
        ),
        tool(
          "student_overview",
          "Mostra frequência recente e pendências de um aluno. Sempre passe a turma quando ela for citada (ex.: Breno da 2ª H).",
          {
            name: { type: "string", description: "Nome do aluno" },
            classroom: { type: "string", description: "Turma do aluno, se informada" }
          },
          %w[name]
        ),
        tool(
          "classroom_overview",
          "Resumo de uma turma: alunos, aulas e pendências.",
          { classroom: { type: "string", description: "Nome da turma" } },
          %w[classroom]
        ),
        tool(
          "attendance_report",
          "Frequência do mês de um aluno ou de uma turma.",
          {
            classroom: { type: "string" },
            student: { type: "string" },
            month: { type: "string", description: "AAAA-MM" }
          }
        ),
        tool(
          "grades_report",
          "Notas e média de um aluno ou de uma turma em um bimestre.",
          {
            classroom: { type: "string" },
            student: { type: "string" },
            bimester: { type: "integer", description: "1 a 4" }
          }
        ),
        tool(
          "monitoring_alerts",
          "Alunos com alerta de nota, atividade ou frequência.",
          {
            classroom: { type: "string" },
            month: { type: "string", description: "AAAA-MM" }
          }
        ),
        tool(
          "recent_lessons",
          "Aulas recentes ou próximas de uma turma.",
          {
            classroom: { type: "string" },
            days: { type: "integer", description: "Janela em dias, padrão 14" }
          }
        ),
        tool(
          "list_projects",
          "Lista os projetos pedagógicos do professor (turma, Professor Nota 10, Escola Nota 10). Não são notas do SIAGE."
        ),
        tool(
          "activity_delivery_status",
          "Lista os alunos de uma atividade com situação (entregue, entregue com atraso, em andamento, não entregou) e data de recebimento. Use quando o professor for escrever recado ou alerta de relatório para o grupo da turma.",
          {
            classroom: { type: "string", description: "Nome da turma" },
            activity: { type: "string", description: "Título da atividade. Se vazio, usa a mais recente da turma." },
            status: { type: "string", description: "Filtrar: entregue, atraso, em andamento, não entregou" }
          },
          %w[classroom]
        )
      ]
    end

    def call(name, arguments = {})
      args = arguments.to_h.stringify_keys

      case name.to_s
      when "list_classrooms" then list_classrooms
      when "search_students" then search_students(args["query"], classroom: args["classroom"])
      when "student_overview" then student_overview(args["name"], classroom: args["classroom"])
      when "classroom_overview" then classroom_overview(args["classroom"])
      when "attendance_report"
        attendance_report(
          classroom: args["classroom"],
          student: args["student"],
          month: args["month"]
        )
      when "grades_report"
        grades_report(
          classroom: args["classroom"],
          student: args["student"],
          bimester: args["bimester"]
        )
      when "monitoring_alerts"
        monitoring_alerts(classroom: args["classroom"], month: args["month"])
      when "recent_lessons"
        recent_lessons(classroom: args["classroom"], days: args["days"])
      when "list_projects" then list_projects
      when "activity_delivery_status"
        activity_delivery_status(
          classroom: args["classroom"],
          activity: args["activity"],
          status: args["status"]
        )
      else
        { error: "Ferramenta desconhecida." }
      end
    rescue StandardError => error
      Rails.logger.warn("[Lira] ferramenta #{name}: #{error.class} #{error.message}")
      { error: "Não consegui consultar esse dado agora." }
    end

    def list_classrooms
      classrooms.map do |classroom|
        {
          name: classroom.name,
          year: classroom.school_year,
          shift: classroom.shift_label,
          students: active_enrollments(classroom).count
        }
      end
    end

    def search_students(query, classroom: nil)
      return { error: "Informe o nome ou a matrícula." } if query.to_s.strip.blank?

      classroom_record = find_classroom(classroom) if classroom.present?
      matches = matching_students(query, classroom: classroom_record)
      if matches.empty? && classroom_record
        return student_not_found(query, classroom: classroom_record)
      end

      payload = student_match_payload(matches.first(8))
      { students: payload, count: payload.size }
    end

    def student_overview(name, classroom: nil)
      classroom_record = find_classroom(classroom) if classroom.present?
      located = locate_student(name, classroom: classroom_record)
      return located if located[:error].present?

      student = located[:student]
      month = Date.current.beginning_of_month
      enrollments = student.enrollments.where(status: "active").includes(:classroom)
      enrollments = enrollments.where(classroom: classroom_record) if classroom_record

      classrooms_data = enrollments.filter_map do |enrollment|
        item = enrollment.classroom
        next if item.blank?

        row = alert_row(item, student, month)
        {
          classroom: item.name,
          attendance_month: row&.attendance_percentage,
          pending_activities: Array(row&.pending_activities).map { |item| item[:activity].title },
          unscored_activities: Array(row&.unscored_activities).map { |item| item[:activity].title },
          grade_alerts: Array(row&.grade_alerts)
        }
      end

      {
        name: student.name,
        registration: student.registration_number,
        classrooms: classrooms_data
      }
    end

    def classroom_overview(name)
      classroom = find_classroom(name)
      return { error: "Não encontrei essa turma." } if classroom.blank?

      month = Date.current.beginning_of_month
      report = Monitoring::AlertReport.new(professor: @professor, classroom: classroom, month: month)
      enrollments = active_enrollments(classroom).includes(:student)

      {
        name: classroom.name,
        year: classroom.school_year,
        shift: classroom.shift_label,
        students: enrollments.map { |item| item.student.name },
        student_count: enrollments.size,
        lessons_this_month: classroom.lessons.where(lesson_date: month.all_month).count,
        alerts: report.summary
      }
    end

    def attendance_report(classroom: nil, student: nil, month: nil)
      period = parse_month(month)
      classroom_record = find_classroom(classroom) if classroom.present?
      student_record = nil
      if student.present?
        located = locate_student(student, classroom: classroom_record)
        return located if located[:error].present?

        student_record = located[:student]
      end

      records = AttendanceRecord
                .where(professor: @professor, attendance_date: period.all_month)
                .includes(enrollment: %i[student classroom])

      records = records.where(enrollments: { classroom_id: classroom_record.id }) if classroom_record
      records = records.where(enrollments: { student_id: student_record.id }) if student_record

      grouped = records.group_by { |item| item.enrollment.student }

      {
        month: I18n.l(period, format: "%B de %Y").capitalize,
        classroom: classroom_record&.name,
        student: student_record&.name,
        students: grouped.map do |item_student, items|
          counts = items.group_by(&:status).transform_values(&:size)
          {
            name: item_student.name,
            present: counts["present"].to_i,
            absent: counts["absent"].to_i,
            justified: counts["justified"].to_i,
            late: counts["late"].to_i,
            percentage: attendance_percentage(items)
          }
        end
      }
    end

    def grades_report(classroom: nil, student: nil, bimester: nil)
      classroom_record = find_classroom(classroom) if classroom.present?
      student_record = nil
      if student.present?
        located = locate_student(student, classroom: classroom_record)
        return located if located[:error].present?

        student_record = located[:student]
      end
      period = bimester.to_i
      period = current_bimester if period < 1 || period > 4

      if classroom_record.blank? && student_record.present?
        rooms = student_record.enrollments.where(status: "active").filter_map(&:classroom)
        if rooms.size > 1
          return {
            error: "Esse aluno está em mais de uma turma. Qual delas?",
            candidates: student_match_payload([student_record])
          }
        end

        classroom_record = rooms.first
      end

      return { error: "Informe a turma ou o aluno." } if classroom_record.blank?

      activities = Grades::BimesterScore.activities_for(classroom_record, period).to_a
      setting = classroom_record.bimester_setting_for(period)
      students = if student_record
                   [student_record]
                 else
                   active_enrollments(classroom_record).includes(:student).map(&:student)
                 end

      {
        classroom: classroom_record.name,
        bimester: period,
        minimum_score: setting.minimum_score,
        students: students.map { |item| grades_for(item, classroom_record, activities, period, setting) }
      }
    end

    def monitoring_alerts(classroom: nil, month: nil)
      classroom_record = find_classroom(classroom) if classroom.present?
      period = parse_month(month)

      if classroom_record
        report = Monitoring::AlertReport.new(
          professor: @professor,
          classroom: classroom_record,
          month: period
        )

        return {
          month: report.month_label,
          classroom: classroom_record.name,
          summary: report.summary,
          students: report.visible_rows.first(20).map { |row| alert_hash(row) }
        }
      end

      classrooms.map do |item|
        report = Monitoring::AlertReport.new(
          professor: @professor,
          classroom: item,
          month: period
        )
        next if report.summary[:total].zero?

        {
          classroom: item.name,
          alerts: report.summary[:total],
          danger: report.summary[:danger],
          students: report.visible_rows.first(8).map { |row| row.student.name }
        }
      end.compact
    end

    def recent_lessons(classroom: nil, days: nil)
      window = days.to_i
      window = 14 if window <= 0
      range = (Date.current - window.days)..(Date.current + window.days)
      lessons = @professor.lessons.where(lesson_date: range).includes(:classroom, :course, :activity)
      classroom_record = find_classroom(classroom) if classroom.present?
      lessons = lessons.where(classroom: classroom_record) if classroom_record

      lessons.order(:lesson_date).limit(20).map do |lesson|
        {
          date: I18n.l(lesson.lesson_date),
          classroom: lesson.classroom.name,
          theme: lesson.theme,
          discipline: lesson.course&.name,
          has_activity: lesson.has_activity,
          activity: lesson.activity&.title
        }
      end
    end

    def list_projects
      @professor.projects.includes(:classrooms, :project_stages).order(:title).map do |project|
        {
          title: project.title,
          kind_label: project.kind_label,
          audience: project.audience_label,
          status: project.status_label,
          progress: project.progress,
          overdue: project.overdue_stages.map(&:title),
          classrooms: project.classrooms.map(&:name)
        }
      end
    end

    def find_classroom(name)
      return if name.blank?

      needle = Lessons::NameMatcher.normalize(name)
      exact = classrooms.select { |classroom| Lessons::NameMatcher.normalize(classroom.name) == needle }
      return exact.first if exact.one?

      matches = matching_classrooms(name)
      matches.one? ? matches.first : nil
    end

    def matching_classrooms(text)
      Lira::Lookup.classrooms_from(text, classrooms)
    end

    def find_student(name, classroom: nil)
      matches = matching_students(name, classroom: classroom)
      matches.one? ? matches.first : nil
    end

    def matching_students(query, classroom: nil)
      classroom ||= find_classroom(query)

      scope = @professor.students.includes(enrollments: :classroom).order(:name)
      if classroom
        ids = Enrollment.where(professor: @professor, classroom: classroom, status: "active").select(:student_id)
        scope = scope.where(id: ids)
      end

      matches = Lira::Lookup.students_from(query, scope)
      return matches if matches.any?

      digits = Lira::Phone.digits(query)
      return [] if digits.blank?

      scope.select { |student| student.registration_number.to_s.include?(digits) }
    end

    def locate_student(name, classroom: nil)
      return { error: "Informe o nome do aluno." } if name.blank?

      matches = matching_students(name, classroom: classroom)
      if matches.one?
        return { student: matches.first }
      end

      if matches.size > 1
        return {
          error: "Há mais de um aluno com esse nome. Diga a turma (por exemplo 2ª H ou 2ª I) para eu não misturar.",
          candidates: student_match_payload(matches)
        }
      end

      student_not_found(name, classroom: classroom)
    end

    def student_not_found(name, classroom: nil)
      if classroom
        others = matching_students(name)
        if others.any?
          return {
            error: "Não encontrei esse aluno na #{classroom.name}. Há alguém com esse nome em outra turma.",
            candidates: student_match_payload(others)
          }
        end

        return { error: "Não encontrei esse aluno na #{classroom.name}." }
      end

      { error: "Não encontrei esse aluno na sua conta." }
    end

    def activity_delivery_status(classroom:, activity: nil, status: nil)
      classroom_record = find_classroom(classroom)
      return { error: "Não encontrei essa turma." } if classroom_record.blank?

      record = find_activity(classroom_record, activity)
      return { error: "Não encontrei essa atividade na #{classroom_record.name}." } if record.blank?

      wanted = normalize_delivery_status(status)
      rows = Documents::ActivityDeliveryReport.delivery_rows(
        classroom: classroom_record,
        activity: record
      )
      listed = wanted ? rows.select { |row| row[:status] == wanted } : rows

      {
        classroom: classroom_record.name,
        activity: record.title,
        due_date: record.due_date,
        bimester: record.bimester,
        status_filter: wanted,
        counts: {
          delivered: rows.count { |row| row[:status] == :delivered },
          delivered_late: rows.count { |row| row[:status] == :delivered_late },
          in_progress: rows.count { |row| row[:status] == :in_progress },
          not_delivered: rows.count { |row| row[:status] == :not_delivered }
        },
        students: listed.map { |row|
          {
            name: row[:student].name,
            status: row[:status].to_s,
            status_label: Documents::ActivityDeliveryReport::STATUS_LABELS[row[:status]],
            submitted_on: row[:submitted_on]
          }
        }
      }
    end

    def student_match_payload(students)
      students.map do |student|
        {
          name: student.name,
          registration: student.registration_number,
          classrooms: student_classroom_names(student)
        }
      end
    end

    private

    def tool(name, description, properties = {}, required = [])
      {
        type: "function",
        function: {
          name: name,
          description: description,
          parameters: {
            type: "object",
            properties: properties,
            required: required
          }
        }
      }
    end

    def find_activity(classroom, title)
      activities = Activity
                   .joins(:lesson)
                   .where(lessons: { classroom_id: classroom.id, professor_id: @professor.id })
                   .includes(:lesson, :activity_recipients, adapted_versions: :activity_recipients)
                   .order("activities.due_date DESC", "activities.id DESC")
      return activities.first if title.blank?

      needle = Lessons::NameMatcher.normalize(title)
      activities.find { |item|
        Lessons::NameMatcher.normalize(item.title).include?(needle) ||
          needle.include?(Lessons::NameMatcher.normalize(item.title))
      } || activities.find { |item| Lessons::NameMatcher.similar?(item.title, title) }
    end

    def normalize_delivery_status(value)
      text = Lessons::NameMatcher.normalize(value.to_s)
      return if text.blank?
      return :not_delivered if text.match?(/nao entreg|sem entrega|pendenc/)
      return :delivered_late if text.match?(/atraso/)
      return :in_progress if text.match?(/andament/)
      return :delivered if text.match?(/entreg/)

      %i[delivered delivered_late in_progress not_delivered].find { |item| item.to_s == text }
    end

    def classrooms
      @classrooms ||= @professor.classrooms.includes(:grade_level).order(:name)
    end

    def active_enrollments(classroom)
      Enrollment.where(professor: @professor, classroom: classroom, status: "active")
    end

    def student_classroom_names(student)
      student.enrollments.where(status: "active").includes(:classroom).map { |item| item.classroom.name }
    end

    def parse_month(value)
      return Date.current.beginning_of_month if value.blank?

      Date.strptime(value.to_s, "%Y-%m")
    rescue ArgumentError
      Date.current.beginning_of_month
    end

    def current_bimester
      ((Date.current.month - 1) / 3) + 1
    end

    def attendance_percentage(records)
      return nil if records.blank?

      total = records.size
      absences = records.count { |record| record.status == "absent" }
      (((total - absences).to_f / total) * 100).round(1)
    end

    def alert_row(classroom, student, month)
      Monitoring::AlertReport
        .new(professor: @professor, classroom: classroom, month: month)
        .student_rows
        .find { |row| row.student.id == student.id }
    end

    def alert_hash(row)
      {
        name: row.student.name,
        severity: row.severity_label,
        tags: row.tags.map { |tag| tag[:label] },
        attendance: row.attendance_percentage,
        pending_activities: row.pending_activities.map { |item| item[:activity].title },
        unscored_activities: row.unscored_activities.map { |item| item[:activity].title },
        grade_alerts: row.grade_alerts
      }
    end

    def grades_for(student, classroom, activities, bimester, setting)
      recovery = RecoveryGrade.find_by(
        professor: @professor,
        classroom: classroom,
        student: student,
        bimester: bimester
      )

      grades = activities.filter_map do |activity|
        next unless activity.assigned_to?(student)
        next if activity.regular? && activity.replacing_version_for(student).present?

        submission = activity.activity_submissions.find { |item| item.student_id == student.id }
        {
          activity: activity.title,
          score: submission&.score
        }
      end

      score = Grades::BimesterScore.new(
        student: student,
        activities: activities,
        recovery: recovery
      )
      average = score.average
      final_score = score.final_score
      situation =
        if NumericScore.recorded?(final_score)
          final_score >= (setting.minimum_score || 6).to_d ? :approved : :recovery
        else
          :without_grades
        end

      {
        name: student.name,
        average: average,
        final_score: final_score,
        situation: SITUATION_LABELS[situation],
        activities: grades
      }
    end
  end
end
