require "test_helper"

class StudentOccurrenceTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "builds a whatsapp recado without counting as absence" do
    professor = Professor.create!(
      name: "Ana Souza",
      email: "occ-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = professor.grade_levels.create!(name: "2º ano")
    classroom = professor.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    student = professor.students.create!(name: "Pedro")
    occurrence = StudentOccurrence.create!(
      professor: professor,
      student: student,
      classroom: classroom,
      occurred_on: Date.current,
      kind: "health",
      body: "Saiu para o posto de saúde."
    )

    assert_equal "Saúde", occurrence.kind_label
    assert_includes occurrence.recado_text, "Pedro"
    assert_includes occurrence.whatsapp_url, "wa.me"
    assert_equal 0, AttendanceRecord.where(professor: professor).count
  end
end
