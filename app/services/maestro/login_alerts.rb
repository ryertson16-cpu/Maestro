module Maestro
  class LoginAlerts
    def initialize(professor)
      @professor = professor
    end

    def toasts
      [siage_toast, *monitoring_toasts].compact
    end

    private

    def siage_toast
      pending = Siage::Ledger.new(professor: @professor).summary[:pending]
      return if pending.zero?

      {
        kind: "error",
        icon: :siage,
        title: "Pendências SIAGE",
        message: siage_message(pending),
        href: helpers.siage_ledger_path,
        action: "Abrir livro",
        duration: 0
      }
    end

    def monitoring_toasts
      Monitoring::AlertReport
        .new(professor: @professor)
        .classroom_alert_breakdown
        .map { |entry| monitoring_toast(entry) }
    end

    def monitoring_toast(entry)
      classroom = entry[:classroom]
      kind = entry[:care].positive? ? "error" : "attention"

      {
        kind: kind,
        icon: :monitoring,
        title: "Monitoramento · #{classroom.name}",
        message: monitoring_message(classroom.name, entry),
        href: helpers.monitoring_path(classroom_id: classroom.id),
        action: "Abrir turma",
        duration: 0
      }
    end

    def siage_message(count)
      if count == 1
        "1 aula ainda está pendente no livro-razão."
      else
        "#{count} aulas ainda estão pendentes no livro-razão."
      end
    end

    def monitoring_message(name, entry)
      parts = []
      parts << students_phrase(entry[:attention], "atenção") if entry[:attention].positive?
      parts << students_phrase(entry[:care], "cuidado") if entry[:care].positive?

      "Na turma #{name} há #{parts.to_sentence}."
    end

    def students_phrase(count, label)
      noun = count == 1 ? "aluno" : "alunos"
      "#{count} #{noun} em #{label}"
    end

    def helpers
      Rails.application.routes.url_helpers
    end
  end
end
