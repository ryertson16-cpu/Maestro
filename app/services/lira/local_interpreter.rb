module Lira
  class LocalInterpreter
    def initialize(toolkit)
      @toolkit = toolkit
    end

    def reply(text)
      message = text.to_s.strip
      return Lira::DailyBriefing.new(professor: @toolkit.professor).wake_text if greeting?(message)

      classroom_matches = @toolkit.matching_classrooms(message)
      classroom = classroom_matches.one? ? classroom_matches.first : nil
      student_matches = @toolkit.matching_students(message, classroom: classroom)

      if student_matches.size > 1
        return Lira::Scope.format_ambiguous_students(
          @toolkit.student_match_payload(student_matches),
          professor: @toolkit.professor
        )
      end

      if classroom.blank? && classroom_matches.size > 1 && student_matches.empty?
        return Lira::Scope.format_ambiguous_classrooms(classroom_matches, professor: @toolkit.professor)
      end

      student = student_matches.one? ? student_matches.first : nil

      result =
        if monitoring?(message)
          @toolkit.monitoring_alerts(classroom: classroom&.name)
        elsif projects?(message)
          @toolkit.list_projects
        elsif grades?(message)
          @toolkit.grades_report(
            classroom: classroom&.name,
            student: student&.name,
            bimester: extract_bimester(message)
          )
        elsif attendance?(message)
          @toolkit.attendance_report(
            classroom: classroom&.name,
            student: student&.name,
            month: extract_month(message)
          )
        elsif lessons?(message)
          @toolkit.recent_lessons(classroom: classroom&.name)
        elsif student.present?
          @toolkit.student_overview(student.name, classroom: classroom&.name)
        elsif classroom.present?
          @toolkit.classroom_overview(classroom.name)
        elsif students_list?(message)
          @toolkit.search_students(extract_query(message) || "a", classroom: classroom&.name)
        elsif classrooms?(message)
          @toolkit.list_classrooms
        end

      return Lira::Scope.fallback(professor: @toolkit.professor) if result.blank?

      Lira::Scope.format_result(
        result,
        student: student,
        classroom: classroom,
        professor: @toolkit.professor,
        topic: Lira::Scope.topic_for(message)
      )
    end

    private

    def greeting?(text)
      Lessons::NameMatcher.normalize(text).match?(/\A(oi|ola|bom dia|boa tarde|boa noite|e ai|hey|lira|maestro)\b/)
    end

    def monitoring?(text)
      text.match?(/monitor|alerta|pendenc|risco|cuidado|aten(c|ç)ao/i)
    end

    def grades?(text)
      text.match?(/nota|m[eé]dia|bimestre|recupera|aprovad/i)
    end

    def attendance?(text)
      text.match?(/frequ|falt|presen|atraso|chamada/i)
    end

    def lessons?(text)
      text.match?(/aula|di[aá]rio|conte[uú]do|tema/i)
    end

    def projects?(text)
      text.match?(/projeto|nota\s*10|portf[oó]lio/i)
    end

    def classrooms?(text)
      text.match?(/turma/i)
    end

    def students_list?(text)
      text.match?(/aluno/i)
    end

    def mentioned_student(text, classroom = nil)
      matches = @toolkit.matching_students(text, classroom: classroom)
      matches.one? ? matches.first : nil
    end

    def mentioned_classroom(text)
      matches = @toolkit.matching_classrooms(text)
      matches.one? ? matches.first : nil
    end

    def extract_bimester(text)
      match = text.match(/(\d)\s*[ºo]?\s*bim/i)
      match&.[](1)
    end

    def extract_month(text)
      return Date.current.strftime("%Y-%m") unless text.match?(/\d{4}-\d{2}|janeiro|fevereiro|mar[cç]o|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro/i)

      months = I18n.t("date.month_names")
      index = months.find_index { |name| name.present? && text.downcase.include?(name.downcase) }
      return Date.current.strftime("%Y-%m") if index.blank?

      Date.new(Date.current.year, index, 1).strftime("%Y-%m")
    end

    def extract_query(text)
      text.sub(/.*alunos?( da| de| do)?/i, "").strip.presence
    end

    def longest_quoted(text)
      text[/"([^"]+)"/, 1] || text[/'([^']+)'/, 1]
    end
  end
end
