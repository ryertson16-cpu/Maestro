require "test_helper"

class StudentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "students-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in @professor

    grade = @professor.grade_levels.create!(name: "3º ano")
    @classroom = @professor.classrooms.create!(
      name: "3ª M",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @student = @professor.students.create!(name: "ANDRIELE YASMIN MONTEIRO DE SOUZA")
    Enrollment.create!(
      professor: @professor,
      student: @student,
      classroom: @classroom,
      enrolled_on: Date.current,
      status: "active"
    )
  end

  test "student profile has a delete button" do
    get student_path(@student)

    assert_response :success
    assert_includes response.body, "Excluir aluno"
    assert_includes response.body, student_path(@student)
  end

  test "destroy removes the student even with enrollment history" do
    delete student_path(@student)

    assert_redirected_to classroom_path(@classroom)
    follow_redirect!
    assert_includes response.body, "foi excluído do cadastro"
    assert_nil Student.find_by(id: @student.id)
    assert_equal 0, Enrollment.where(student_id: @student.id).count
  end
end
