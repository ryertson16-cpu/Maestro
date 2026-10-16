require "test_helper"

class Monitoring::StudentAlertTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "trajectory risk counts as an attendance alert" do
    row = Monitoring::StudentAlert.new(
      student: Struct.new(:name).new("Maria"),
      classroom: Struct.new(:name).new("3ª M"),
      month: Date.new(2026, 10, 1),
      pending_activities: [],
      unscored_activities: [],
      grade_alerts: [],
      attendance_percentage: 82.0,
      attendance_alert: nil,
      trajectory_alert: {
        severity: :warning,
        label: "Risco à frente",
        reason: "Mais 1 falta neste mês e a frequência cai."
      }
    )

    assert row.alerted?
    assert_equal :warning, row.severity
    assert row.matches_filter?("attendance")
    assert_includes row.tags.map { |tag| tag[:label] }, "Risco à frente"
  end

  test "75 percent is not an attendance warning" do
    row = Monitoring::StudentAlert.new(
      student: Struct.new(:name).new("João"),
      classroom: Struct.new(:name).new("3ª M"),
      month: Date.new(2026, 10, 1),
      pending_activities: [],
      unscored_activities: [],
      grade_alerts: [],
      attendance_percentage: 75.0,
      attendance_alert: Attendance::Frequency.below_minimum?(75.0) ? { severity: :danger } : nil
    )

    assert_not row.alerted?
  end
end
