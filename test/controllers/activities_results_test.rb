require "test_helper"

class ActivitiesResultsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana",
      email: "exam-ui-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "3º ano")
    classroom = @professor.classrooms.create!(name: "3ª A", school_year: 2026, grade_level: grade, active: true)
    lesson = @professor.lessons.create!(
      classroom: classroom,
      lesson_date: Date.current,
      theme: "Função",
      has_activity: true,
      siage_time_slot: "1"
    )
    @activity = lesson.create_activity!(
      title: "Prova 3",
      activity_type: "Prova",
      due_date: Date.current,
      bimester: 4,
      weight: 1,
      maximum_score: 10
    )
    item = @activity.activity_questions.create!(
      position: 1,
      prompt: "2+2?",
      kind: "objective",
      choices: [ { "letter" => "A", "text" => "4" }, { "letter" => "B", "text" => "3" } ],
      correct_letter: "A",
      points: 10
    )
    student = @professor.students.create!(name: "Ana Beatriz Rocha")
    Enrollment.create!(professor: @professor, student: student, classroom: classroom, enrolled_on: Date.current, status: "active")
    ActivitySubmission.create!(
      activity: @activity,
      student: student,
      professor: @professor,
      score: 10,
      submitted_on: Date.current,
      answers: { item.id.to_s => "A" }
    )
    sign_in @professor
  end

  test "result page shows identified student and export" do
    get results_activity_path(@activity)

    assert_response :success
    assert_match "Ana Beatriz Rocha", response.body
    assert_match "Exportar notas", response.body
    assert_match "Q1", response.body
    assert_match "Identificado", response.body
  end

  test "grades export is a pdf" do
    get grades_export_activity_path(@activity, format: :pdf)

    assert_response :success
    assert_match "application/pdf", response.media_type
  end
end
