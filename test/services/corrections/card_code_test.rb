require "test_helper"

class Corrections::CardCodeTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "payload is a short pin plus student id" do
    professor = Professor.create!(
      name: "Ana",
      email: "pin-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = professor.grade_levels.create!(name: "2º ano")
    classroom = professor.classrooms.create!(name: "2ª A", school_year: 2026, grade_level: grade, active: true)
    lesson = professor.lessons.create!(
      classroom: classroom,
      lesson_date: Date.current,
      theme: "Célula",
      siage_time_slot: "1",
      has_activity: true
    )
    activity = lesson.create_activity!(
      title: "Prova",
      activity_type: "Prova",
      due_date: Date.current,
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
    student = professor.students.create!(name: "João")

    payload = Corrections::CardCode.payload(activity, student)
    parsed = Corrections::CardCode.parse(payload)

    assert_match(/\AM\d{6}A#{student.id}\z/, payload)
    assert_equal activity.reload.correction_pin, parsed[:pin]
    assert_equal student.id, parsed[:student_id]
    assert_operator payload.length, :<, 20
  end
end
