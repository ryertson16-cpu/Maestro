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
    assert_match "Editar acertos", response.body
    assert_match "Apagar", response.body
  end

  test "clear results removes the scored correction" do
    assert_difference -> { ActivitySubmission.where(activity: @activity).count }, -1 do
      delete clear_results_activity_path(@activity)
    end

    assert_redirected_to results_activity_path(@activity)
    follow_redirect!
    assert_match "Ainda não há cartão lido", response.body
  end

  test "clear one student keeps the other correction" do
    other = @professor.students.create!(name: "Bruno Lima")
    Enrollment.create!(professor: @professor, student: other, classroom: @activity.lesson.classroom, enrolled_on: Date.current, status: "active")
    ActivitySubmission.create!(
      activity: @activity,
      student: other,
      professor: @professor,
      score: 4,
      submitted_on: Date.current,
      answers: {}
    )
    kept = ActivitySubmission.find_by!(activity: @activity, student: @activity.lesson.classroom.students.find_by!(name: "Ana Beatriz Rocha"))

    assert_difference -> { ActivitySubmission.where(activity: @activity).count }, -1 do
      delete clear_student_result_activity_path(@activity, student_id: other)
    end

    assert_redirected_to results_activity_path(@activity)
    assert ActivitySubmission.exists?(kept.id)
    assert_nil ActivitySubmission.find_by(activity: @activity, student: other)
  end

  test "editing hits updates the score" do
    student = @activity.lesson.classroom.students.find_by!(name: "Ana Beatriz Rocha")
    item = @activity.activity_questions.first

    get edit_result_activity_path(@activity, student_id: student)
    assert_response :success
    assert_match "Ana Beatriz Rocha", response.body
    assert_match "Salvar acertos", response.body

    patch update_result_activity_path(@activity, student_id: student),
          params: { answers: { item.id.to_s => "B" } }

    assert_redirected_to results_activity_path(@activity)
    assert_equal 0, ActivitySubmission.find_by!(activity: @activity, student: student).score.to_f
  end

  test "grades export is a pdf" do
    get grades_export_activity_path(@activity, format: :pdf)

    assert_response :success
    assert_match "application/pdf", response.media_type
  end
end
