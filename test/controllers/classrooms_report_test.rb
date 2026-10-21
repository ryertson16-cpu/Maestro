require "test_helper"

class ClassroomsReportTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "class-report-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "2º ano")
    @classroom = @professor.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    student = @professor.students.create!(name: "Maria Souza")
    Enrollment.create!(
      professor: @professor,
      student: student,
      classroom: @classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    sign_in @professor
  end

  test "classroom card offers a roster pdf" do
    get classrooms_path

    assert_response :success
    assert_includes response.body, report_classroom_path(@classroom)
    assert_includes response.body, "Relatório"
  end

  test "downloads the classroom student roster pdf" do
    get report_classroom_path(@classroom)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/relacao-alunos-2-f/, response.headers["Content-Disposition"])
  end
end
