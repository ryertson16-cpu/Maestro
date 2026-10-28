require "test_helper"

class SiageLedgersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      email: "siage-ui-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "3º ano")
    @classroom = @professor.classrooms.create!(
      name: "3ª O",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    student = @professor.students.create!(name: "Maria Silva")
    Enrollment.create!(
      professor: @professor,
      student: student,
      classroom: @classroom,
      enrolled_on: Date.new(2026, 2, 2),
      status: "active"
    )
    lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.new(2026, 10, 20),
      theme: "Simulado ENEM — CN e Matemática",
      has_activity: true,
      siage_time_slot: "1º tempo"
    )
    activity = lesson.create_activity!(
      title: "Simulado ENEM — CN e Matemática",
      activity_type: "Simulado ENEM",
      due_date: Date.new(2026, 10, 20),
      bimester: 4,
      weight: 1,
      maximum_score: 10
    )
    ActivitySubmission.create!(
      activity: activity,
      student: student,
      professor: @professor,
      score: 8.0,
      submitted_on: Date.new(2026, 10, 20)
    )
    sign_in @professor
  end

  test "notas block lists simulado enem json without a prior export" do
    get siage_ledger_path

    assert_response :success
    assert_includes response.body, "Notas no SIAGE"
    assert_includes response.body, "Simulado ENEM — CN e Matemática"
    assert_includes response.body, "/siage/grades?"
    assert_includes response.body, "bimester=4"
  end
end
