require "test_helper"

class Maestro::TodayBriefingTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "ana-today-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "2º ano")
    classroom = @professor.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    student = @professor.students.create!(name: "João")
    Enrollment.create!(
      professor: @professor,
      classroom: classroom,
      student: student,
      enrolled_on: Date.new(2026, 2, 2),
      status: "active"
    )
  end

  test "saturday without a calendar mark is not a school day and has no missing calls" do
    briefing = Maestro::TodayBriefing.new(professor: @professor, date: Date.new(2026, 10, 10))

    assert_not briefing.school_day?
    assert_empty briefing.classrooms_waiting_call
    assert_empty briefing.slots
  end

  test "saturday marked as saturday school counts missing calls" do
    @professor.school_calendar_days.create!(
      day: Date.new(2026, 10, 10),
      kind: "saturday_school"
    )

    briefing = Maestro::TodayBriefing.new(professor: @professor, date: Date.new(2026, 10, 10))

    assert briefing.school_day?
    assert_equal [ "2ª F" ], briefing.classrooms_waiting_call.map(&:name)
  end

  test "weekday holiday has no missing calls" do
    @professor.school_calendar_days.create!(
      day: Date.new(2026, 10, 12),
      kind: "holiday",
      name: "Nossa Senhora Aparecida"
    )

    briefing = Maestro::TodayBriefing.new(professor: @professor, date: Date.new(2026, 10, 12))

    assert_not briefing.school_day?
    assert_empty briefing.classrooms_waiting_call
  end

  test "plain weekday still lists classrooms waiting for the call" do
    briefing = Maestro::TodayBriefing.new(professor: @professor, date: Date.new(2026, 10, 9))

    assert briefing.school_day?
    assert_equal [ "2ª F" ], briefing.classrooms_waiting_call.map(&:name)
  end

  test "week strip marks saturday as current and not a school day" do
    briefing = Maestro::TodayBriefing.new(professor: @professor, date: Date.new(2026, 10, 10))
    days = briefing.week_days

    assert_equal %w[Seg Ter Qua Qui Sex Sáb Dom], days.map(&:short_label)
    saturday = days.find(&:current)
    assert_equal Date.new(2026, 10, 10), saturday.date
    assert_not saturday.school_day
    assert saturday.current
    assert days.first.past
    assert_not days.last.past
    assert_not days.last.current
  end
end

