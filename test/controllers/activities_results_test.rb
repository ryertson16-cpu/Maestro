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
    assert_match "Todos os gabaritos foram corrigidos", response.body
    assert_match "Corrigido", response.body
    assert_match "Correção concluída", response.body
  end

  test "closing the correction marks students without a card as absent from the exam" do
    missing = @professor.students.create!(name: "Carla Souza")
    Enrollment.create!(
      professor: @professor,
      student: missing,
      classroom: @activity.lesson.classroom,
      enrolled_on: Date.current,
      status: "active"
    )

    post close_correction_activity_path(@activity)

    assert_redirected_to results_activity_path(@activity)
    assert @activity.reload.correction_closed?
    assert_equal "present", attendance_status_for("Ana Beatriz Rocha")
    assert_equal "absent", attendance_status_for("Carla Souza")
    assert ActivitySubmission.find_by!(activity: @activity, student: missing).missed_exam?
    kept = ActivitySubmission.find_by!(activity: @activity, student: @activity.lesson.classroom.students.find_by!(name: "Ana Beatriz Rocha"))
    assert_not kept.missed_exam?
    assert_equal 10, kept.score.to_f

    follow_redirect!
    assert_match "1 gabarito corrigido", response.body
    assert_match "1 gabarito ficou sem correção", response.body
    assert_match "Aluno faltou a prova", response.body
  end

  test "result page lists students still without a correction" do
    @professor.students.create!(name: "Carla Souza").tap do |student|
      Enrollment.create!(
        professor: @professor,
        student: student,
        classroom: @activity.lesson.classroom,
        enrolled_on: Date.current,
        status: "active"
      )
    end

    get results_activity_path(@activity)

    assert_response :success
    assert_match "Ainda faltam gabaritos", response.body
    assert_match "Carla Souza", response.body
    assert_match "Sem correção", response.body
    assert_no_match "Todos os gabaritos foram corrigidos", response.body
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

  private

  def attendance_status_for(name)
    student = @activity.lesson.classroom.students.find_by!(name: name)
    enrollment = Enrollment.find_by!(student: student, classroom: @activity.lesson.classroom)
    AttendanceRecord.find_by!(
      enrollment: enrollment,
      lesson: @activity.lesson,
      attendance_date: @activity.lesson.lesson_date
    ).status
  end
end
