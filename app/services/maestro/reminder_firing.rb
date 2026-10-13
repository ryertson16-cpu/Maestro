module Maestro
  class ReminderFiring
    def initialize(professor, now: Time.current)
      @professor = professor
      @now = now
    end

    def call
      due = @professor.reminders.due.where("remind_at <= ?", @now).to_a
      due.each { |reminder| fire(reminder) }
      due
    end

    private

    def fire(reminder)
      return if reminder.fired?

      notice = @professor.automation_notices.create!(
        kind: "reminder",
        title: "Lembrete",
        body: reminder.title,
        fingerprint: "reminder:#{reminder.id}",
        url: Rails.application.routes.url_helpers.root_path
      )

      reminder.update!(fired_at: @now, automation_notice_id: notice.id)
    rescue ActiveRecord::RecordNotUnique
      reminder.update!(fired_at: @now) unless reminder.fired?
    end
  end
end
