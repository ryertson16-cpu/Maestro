require "test_helper"

class ActivitiesDestroyTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "destroy-act-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "3º ano")
    @classroom = @professor.classrooms.create!(
      name: "3ª M",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @student = @professor.students.create!(name: "Maria Silva")
    @enrollment = Enrollment.create!(
      professor: @professor,
      student: @student,
      classroom: @classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    sign_in @professor
  end

  test "destroy button appears on the selected activity card" do
    activity = create_regular_activity

    get grade_levels_path(classroom_id: @classroom.id, activity_id: activity.id)

    assert_response :success
    assert_select "a", text: "Excluir atividade"
  end

  test "destroying an activity removes submissions questions and adapted copies" do
    activity = create_regular_activity
    activity.activity_questions.create!(
      prompt: "O que é ATP?",
      kind: "objective",
      position: 1,
      points: 1,
      choices: [{ "letter" => "A", "text" => "energia" }],
      correct_letter: "A"
    )
    ActivitySubmission.create!(
      activity: activity,
      student: @student,
      professor: @professor,
      score: 8.0,
      submitted_on: Date.current
    )
    adapted = activity.adapted_versions.create!(
      lesson: activity.lesson,
      title: "#{activity.title} (adaptada)",
      activity_type: activity.activity_type,
      due_date: activity.due_date,
      bimester: activity.bimester,
      weight: 1,
      maximum_score: 10,
      adapted: true,
      adaptation_kind: "reduced",
      grade_mode: "replaces",
      recipient_student_ids: [@student.id]
    )
    ActivitySubmission.create!(
      activity: adapted,
      student: @student,
      professor: @professor,
      score: 7.0,
      submitted_on: Date.current
    )
    lesson = activity.lesson

    delete activity_path(activity, classroom_id: @classroom.id)

    assert_redirected_to grade_levels_path(classroom_id: @classroom.id)
    assert_nil Activity.find_by(id: activity.id)
    assert_nil Activity.find_by(id: adapted.id)
    assert_equal 0, ActivitySubmission.where(activity_id: [activity.id, adapted.id]).count
    assert_equal 0, ActivityQuestion.where(activity_id: activity.id).count
    assert Lesson.exists?(lesson.id)
    refute lesson.reload.has_activity?
  end

  test "destroying an imported online activity also removes its generated lesson and attendance" do
    created = Activities::OnlineFormImporter.new(professor: @professor).import!(
      title: "Questionário online",
      lesson_date: Date.new(2026, 10, 19),
      course_id: nil,
      items: [
        {
          classroom_id: @classroom.id,
          student_id: @student.id,
          score: 9.0,
          submitted_at: Time.zone.parse("2026-10-19 10:00")
        }
      ]
    )
    activity = created.first[:activity]
    lesson = activity.lesson
    attendance = AttendanceRecord.find_by(enrollment: @enrollment, lesson: lesson)
    assert attendance

    delete activity_path(activity)

    assert_nil Activity.find_by(id: activity.id)
    assert_nil Lesson.find_by(id: lesson.id)
    assert_nil AttendanceRecord.find_by(id: attendance.id)
    assert_equal 0, ActivitySubmission.where(student: @student).count
  end

  test "another professor cannot destroy the activity" do
    activity = create_regular_activity
    other = Professor.create!(
      name: "Outro",
      email: "other-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in other

    delete activity_path(activity)

    assert_redirected_to grade_levels_path
    assert Activity.exists?(activity.id)
  end

  private

  def create_regular_activity
    lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.current,
      theme: "Célula",
      has_activity: true,
      siage_time_slot: "1º tempo"
    )
    lesson.create_activity!(
      title: "Lista genética",
      activity_type: "Lista de exercícios",
      due_date: Date.current,
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
  end
end
