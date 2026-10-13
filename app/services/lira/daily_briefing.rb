module Lira
  class DailyBriefing
    def initialize(professor:, date: Date.current)
      @professor = professor
      @briefing = Maestro::TodayBriefing.new(professor: professor, date: date)
    end

    def wake_text
      Lira::Scope.format_wake(
        professor: @professor,
        weekday_label: @briefing.weekday_label,
        date_label: I18n.l(@briefing.date),
        day_lines: day_lines
      )
    end

    def command_text
      Lira::Scope.format_today_command(
        professor: @professor,
        weekday_label: @briefing.weekday_label,
        date_label: I18n.l(@briefing.date),
        day_lines: day_lines
      )
    end

    private

    def day_lines
      lines = []

      if !@briefing.school_day?
        lines << "#{Lira::Scope.icon(:lesson)} Dia sem aula no calendário."
      elsif @briefing.slots.any?
        lines << "#{Lira::Scope.icon(:lesson)} Aulas:"
        @briefing.slots.each do |slot|
          mark = slot.called ? "#{Lira::Scope.icon(:ok)} chamada ok" : "#{Lira::Scope.icon(:alert)} falta chamada"
          lines << "#{Lira::Scope.icon(:lesson)} #{slot.entry.time_slot_label} · #{slot.entry.classroom.name} (#{mark})"
        end
      else
        lines << "#{Lira::Scope.icon(:lesson)} Nenhum horário de aula cadastrado para hoje."
      end

      waiting = @briefing.classrooms_waiting_call
      lines << "#{Lira::Scope.icon(:attendance)} Chamada em aberto: #{waiting.map(&:name).to_sentence}." if waiting.any?

      if @briefing.siage_pending_count.positive? || @briefing.siage_failed_count.positive?
        lines << "#{Lira::Scope.icon(:siage)} SIAGE: #{@briefing.siage_pending_count} pendente(s), #{@briefing.siage_failed_count} falha(s)."
      end

      if @briefing.monitoring_alert_count.positive?
        lines << "#{Lira::Scope.icon(:alert)} Monitoramento: #{@briefing.monitoring_alert_count} aluno(s) em alerta."
      end

      if @briefing.overdue_projects_count.positive?
        lines << "#{Lira::Scope.icon(:project)} Projetos atrasados: #{@briefing.overdue_projects_count} (não entram no SIAGE)."
      end

      unless @briefing.work_pending? || !@briefing.school_day?
        lines << "#{Lira::Scope.icon(:ok)} Nada pendente neste momento."
      end

      lines
    end
  end
end
