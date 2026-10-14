module Maestro
  class AutomationRunner
    def initialize(professor, now: Time.current)
      @professor = professor
      @now = now
    end

    def call
      AutomationRule.ensure_defaults_for!(@professor)

      @professor.automation_rules.enabled.find_each do |rule|
        next unless rule.due?(@now)
        next unless send(:"run_#{rule.kind}", rule)

        rule.mark_ran!(@now)
      end
    end

    private

    def run_morning_call(rule)
      briefing = Maestro::TodayBriefing.new(professor: @professor, date: @now.to_date)
      if !briefing.school_day?
        return true
      end

      waiting = briefing.classrooms_waiting_call
      if waiting.empty?
        return @now.hour >= 18
      end

      names = waiting.map(&:name)
      classroom = waiting.first
      record_notice(
        rule: rule,
        fingerprint: "morning_call:#{@now.to_date}:#{waiting.map(&:id).sort.join(",")}",
        title: "Chamada em aberto",
        body: call_body(names),
        url: attendance_url(classroom)
      )
      true
    end

    def run_siage_pending(rule)
      summary = Siage::Ledger.new(professor: @professor).summary
      pending = summary[:pending].to_i
      failed = summary[:failed].to_i
      return true if pending.zero? && failed.zero?

      parts = []
      parts << "#{pending} #{pending == 1 ? "aula pendente" : "aulas pendentes"}" if pending.positive?
      parts << "#{failed} #{failed == 1 ? "falha" : "falhas"}" if failed.positive?

      record_notice(
        rule: rule,
        fingerprint: "siage_pending:#{@now.to_date}",
        title: "SIAGE",
        body: "Há #{parts.to_sentence} no livro-razão.",
        url: helpers.siage_ledger_path
      )
      true
    end

    def run_monitoring(rule)
      report = Monitoring::AlertReport.new(professor: @professor)
      total = report.total_alert_count.to_i
      return true if total.zero?

      record_notice(
        rule: rule,
        fingerprint: "monitoring:#{@now.to_date}",
        title: "Monitoramento",
        body: monitoring_body(total),
        url: helpers.monitoring_path
      )
      true
    end

    def run_weekly_backup(rule)
      record_notice(
        rule: rule,
        fingerprint: "weekly_backup:#{@now.to_date.cwyear}-#{@now.to_date.cweek}",
        title: "Backup do caderno",
        body: "Os dados ficam só neste computador. Guarde uma cópia (pasta do Maestro ou exportação) para não perder o ano letivo.",
        url: helpers.settings_path
      )
      true
    end

    def record_notice(rule:, fingerprint:, title:, body:, url:)
      notice = @professor.automation_notices.find_or_initialize_by(fingerprint: fingerprint)
      created = notice.new_record?
      notice.kind = rule.kind
      notice.title = title
      notice.body = body
      notice.url = url
      notice.save!

      if created && rule.whatsapp?
        Maestro::DeliverAutomationWhatsappJob.perform_later(notice.id)
      end

      notice
    end

    def call_body(names)
      if names.one?
        "Ainda não houve chamada na turma #{names.first}."
      else
        "Ainda não houve chamada em #{names.to_sentence}."
      end
    end

    def monitoring_body(total)
      if total == 1
        "1 aluno está em alerta de nota, atividade ou frequência."
      else
        "#{total} alunos estão em alerta de nota, atividade ou frequência."
      end
    end

    def attendance_url(classroom)
      helpers.attendance_records_path(
        classroom_id: classroom.id,
        attendance_date: @now.to_date
      )
    end

    def helpers
      Rails.application.routes.url_helpers
    end
  end
end
