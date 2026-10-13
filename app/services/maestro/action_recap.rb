module Maestro
  class ActionRecap
    def initialize(professor)
      @professor = professor
    end

    def attendance(lesson:, classroom:, exporting: false)
      lines = [ call_line(lesson, classroom) ]
      lines << siage_line(lesson, classroom) if exporting

      payload(
        lines: lines,
        href: helpers.siage_ledger_path,
        action: "Livro SIAGE"
      )
    end

    def lesson_saved(lesson, updated: false)
      payload(
        lines: [ lesson_line(lesson, updated: updated) ],
        href: helpers.attendance_records_path(
          classroom_id: lesson.classroom_id,
          attendance_date: lesson.lesson_date
        ),
        action: "Lançar frequência"
      )
    end

    def grades(activity, classroom:)
      payload(lines: [ grades_line(activity, classroom) ])
    end

    def recovery(classroom:, bimester:, student_name: nil)
      payload(lines: [ recovery_line(classroom, bimester, student_name) ])
    end

    private

    def payload(lines:, href: nil, action: nil)
      {
        kind: "maestro",
        title: Lira::NAME,
        message: greeting,
        lines: lines,
        href: href,
        action: action,
        duration: 7000
      }.compact
    end

    def greeting
      addressed = [ @professor.courtesy_role, @professor.greeting_name ].compact.join(" ")
      "Pronto, #{addressed}. Ficou no caderno."
    end

    def call_line(lesson, classroom)
      line(
        "Chamada",
        [ { text: "registrei a frequência da turma " } ] +
          classroom_parts(classroom) +
          slot_parts(lesson) +
          bimester_parts(bimester_for(lesson))
      )
    end

    def siage_line(lesson, classroom)
      line(
        "SIAGE",
        [ { text: "preparei o JSON da turma " } ] +
          classroom_parts(classroom) +
          slot_parts(lesson) +
          [ { text: "." } ]
      )
    end

    def lesson_line(lesson, updated:)
      verb = updated ? "atualizei" : "registrei"
      topic = lesson.theme.to_s.strip.presence

      parts = [ { text: "#{verb} a aula da turma " } ]
      parts.concat(classroom_parts(lesson.classroom))
      if topic
        parts << { text: " com o tópico " }
        parts << { text: topic, bold: true }
      end
      parts.concat(bimester_parts(bimester_for(lesson)))
      line("Aula", parts)
    end

    def grades_line(activity, classroom)
      title = activity.title.to_s.strip.presence || "atividade"
      line(
        "Notas",
        [
          { text: "registrei as notas da atividade " },
          { text: title, bold: true },
          { text: " da turma " }
        ] + classroom_parts(classroom) + bimester_parts(activity.bimester)
      )
    end

    def recovery_line(classroom, bimester, student_name)
      parts = [ { text: "registrei a nota de recuperação" } ]
      if student_name.present?
        parts << { text: " de " }
        parts << { text: student_name, bold: true }
      end
      parts << { text: " da turma " }
      parts.concat(classroom_parts(classroom))
      parts.concat(bimester_parts(bimester))
      line("Notas", parts)
    end

    def classroom_parts(classroom)
      name = classroom.respond_to?(:name) ? classroom.name : classroom.to_s
      [ { text: name.to_s.strip.presence || "turma", bold: true } ]
    end

    def slot_parts(lesson)
      slot = lesson&.siage_time_slot.to_s.strip.presence
      return [] if slot.blank?

      [ { text: ", " }, { text: slot, bold: true } ]
    end

    def bimester_parts(number)
      return [ { text: "." } ] if number.blank?

      [ { text: " para o " }, { text: "#{number}º bimestre", bold: true }, { text: "." } ]
    end

    def bimester_for(lesson)
      return if lesson.blank?

      date = lesson.try(:lesson_date)
      Siage.bimester_for_date(date) if date.present?
    end

    def line(label, parts)
      { label: label, parts: parts }
    end

    def helpers
      Rails.application.routes.url_helpers
    end
  end
end
