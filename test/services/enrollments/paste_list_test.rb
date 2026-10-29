require "test_helper"

class Enrollments::PasteListTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana",
      email: "lista-#{SecureRandom.hex(4)}@maestro.test",
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
  end

  test "parses name and optional registration" do
    assert_equal(
      { name: "Maria Silva", registration_number: "2026001" },
      Enrollments::PasteList.parse_line("Maria Silva, 2026001")
    )
    assert_equal(
      { name: "Carlos Lima", registration_number: nil },
      Enrollments::PasteList.parse_line("Carlos Lima")
    )
    assert_nil Enrollments::PasteList.parse_line("nome")
  end

  test "creates students and enrolls them in the classroom" do
    result = Enrollments::PasteList.new(
      professor: @professor,
      classroom: @classroom,
      text: "Ana Beatriz\nCarlos Lima, 2026123"
    ).call

    assert_equal [], result.errors
    assert_equal 2, result.imported
    assert_equal 2, result.created_students
    assert_equal 2, @classroom.students.count
    assert_equal "2026123", @professor.students.find_by(name: "Carlos Lima").registration_number
    generated = @professor.students.find_by(name: "Ana Beatriz").registration_number
    assert_match(/\AMAE2026[A-Z0-9]+\d{3}\z/, generated)
  end

  test "skips students already in the classroom" do
    student = @professor.students.create!(name: "Ana Beatriz")
    @professor.enrollments.create!(
      student: student,
      classroom: @classroom,
      enrolled_on: Date.current,
      status: "active"
    )

    result = Enrollments::PasteList.new(
      professor: @professor,
      classroom: @classroom,
      text: "Ana Beatriz"
    ).call

    assert_equal 0, result.imported
    assert_equal 1, result.skipped
  end
end
