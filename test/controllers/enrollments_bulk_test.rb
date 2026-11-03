require "test_helper"

class EnrollmentsBulkTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana",
      email: "bulk-#{SecureRandom.hex(4)}@maestro.test",
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
    @student = @professor.students.create!(name: "Maria Silva", active: true)
    sign_in @professor
  end

  test "matricular alunos page lists students in the classroom" do
    get bulk_new_enrollments_path, params: { classroom_id: @classroom.id }

    assert_response :success
    assert_includes response.body, "Matricular alunos"
    assert_includes response.body, @student.name
    assert_includes response.body, bulk_create_enrollments_path(@classroom)
  end

  test "enrolls selected students in the classroom" do
    post bulk_create_enrollments_path(@classroom), params: {
      classroom_id: @classroom.id,
      student_ids: [@student.id]
    }

    assert_redirected_to classroom_path(@classroom)
    enrollment = Enrollment.find_by(student: @student, classroom: @classroom)
    assert_equal "active", enrollment.status
  end
end
