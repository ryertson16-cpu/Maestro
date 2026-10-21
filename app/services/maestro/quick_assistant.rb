module Maestro
  class QuickAssistant
    def initialize(professor)
      @professor = professor
    end

    def call(text, forced_reminder: false)
      parser = ReminderParser.new(text, forced: forced_reminder)
      if parser.reminder_intent?
        parsed = parser.parse
        return { type: "error", message: parsed.error } if parsed.error.present?

        reminder = @professor.reminders.create!(
          title: parsed.title,
          remind_at: parsed.remind_at,
          source_text: text.to_s.strip
        )

        return {
          type: "reminder",
          reminder: ReminderCard.new(reminder).as_json
        }
      end

      answer = CommandInterpreter.new(@professor).reply(text)
      if answer.blank?
        answer = Lira::LocalInterpreter.new(Lira::Toolkit.new(@professor)).reply(text)
      end

      message = answer.to_s.strip.presence || "Pode falar um lembrete, como: me lembra da reunião amanhã às 19h."
      {
        type: "text",
        message: Lira::Scope.with_opening(message, professor: @professor, topic: Lira::Scope.topic_for(text))
      }
    end
  end
end
