require "test_helper"

class GradeLevelsActivityNoticeTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      preferred_name: "Ana",
      sex: "female",
      email: "notice-#{SecureRandom.hex(4)}@maestro.test",
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
    lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.yesterday,
      theme: "Relatório",
      siage_time_slot: "1",
      has_activity: true
    )
    @activity = lesson.create_activity!(
      title: "Lista de genética",
      activity_type: "Lista de exercícios",
      due_date: Date.yesterday,
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
    pending = @professor.students.create!(name: "Carlos Mendes")
    delivered = @professor.students.create!(name: "Maria Lima")
    [pending, delivered].each do |student|
      Enrollment.create!(
        professor: @professor,
        student: student,
        classroom: @classroom,
        enrolled_on: Date.current,
        status: "active"
      )
    end
    ActivitySubmission.create!(
      activity: @activity,
      student: delivered,
      professor: @professor,
      submitted_on: Date.yesterday
    )
    sign_in @professor
  end

  test "activity card offers the group notice" do
    get grade_levels_path(classroom_id: @classroom.id, activity_id: @activity.id)

    assert_response :success
    assert_select "a", text: "Aviso do grupo"
  end

  test "notice page lists pending students for WhatsApp" do
    get activity_notice_grade_levels_path(
      classroom_id: @classroom.id,
      activity_id: @activity.id,
      status: "não entregou"
    )

    assert_response :success
    assert_includes response.body, "Carlos Mendes"
    refute_includes response.body, "Maria Lima"
    assert_includes response.body, "Copiar aviso"
  end
end
