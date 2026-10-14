require "test_helper"

class MaestroAutomationRunnerTest < ActiveSupport::TestCase
  test "morning call is due after the scheduled hour" do
    rule = AutomationRule.new(
      kind: "morning_call",
      enabled: true,
      hour: 7,
      minute: 30
    )

    assert rule.due?(Time.zone.parse("2026-10-05 08:00"))
    refute rule.due?(Time.zone.parse("2026-10-05 07:00"))
  end

  test "weekly backup only runs on monday" do
    rule = AutomationRule.new(
      kind: "weekly_backup",
      enabled: true,
      hour: 16,
      minute: 0
    )

    assert rule.due?(Time.zone.parse("2026-10-05 16:30"))
    refute rule.due?(Time.zone.parse("2026-10-06 16:30"))
  end

  test "creates a backup notice once per week" do
    professor = Professor.create!(
      name: "Ana",
      email: "ana-automacao-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )

    notice = nil
    travel_to Time.zone.parse("2026-10-05 16:30") do
      Maestro::AutomationRunner.new(professor).call
      notice = professor.automation_notices.find_by(kind: "weekly_backup")
      Maestro::AutomationRunner.new(professor).call
    end

    assert_not_nil notice
    assert_equal 1, professor.automation_notices.where(kind: "weekly_backup").count
    assert_match(/neste computador/i, notice.body)
  end
end
