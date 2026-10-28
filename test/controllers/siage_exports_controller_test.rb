require "test_helper"

class SiageExportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "siage-export-#{SecureRandom.hex(4)}@maestro.test",
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
    @lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.current,
      theme: "Célula",
      siage_time_slot: "1"
    )
  end

  test "downloads one spreadsheet for pending lessons across classrooms" do
    sign_in @professor
    other = @professor.classrooms.create!(
      name: "2ª G",
      school_year: 2026,
      grade_level: @professor.grade_levels.first,
      active: true
    )
    @professor.lessons.create!(
      classroom: other,
      lesson_date: Date.current,
      theme: "Outra",
      siage_time_slot: "2"
    )

    get siage_ledger_export_path

    assert_response :success
    assert_match "siage-pendentes-todas-as-turmas.csv", response.headers["Content-Disposition"]
    body = response.body.force_encoding("UTF-8")
    assert_includes body, "2ª SÉRIE F"
    assert_includes body, "2ª SÉRIE G"
  end

  test "grades export can be json or spreadsheet" do
    sign_in @professor
    student = @professor.students.create!(name: "Ana")
    Enrollment.create!(
      professor: @professor,
      classroom: @classroom,
      student: student,
      enrolled_on: Date.new(2026, 2, 2),
      status: "active"
    )

    get siage_grades_export_path(classroom_id: @classroom.id, bimester: 4)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "grades", json["kind"]
    assert_equal "Ana", json["grades"].first["name"]

    get siage_grades_export_path(classroom_id: @classroom.id, bimester: 4, spreadsheet: 1)
    assert_response :success
    body = response.body.force_encoding("UTF-8")
    assert_includes body, "Aluno"
    assert_includes body, "1ª unidade"
    assert_includes body, "Ana"
    refute_includes body, "REC GLOBAL"
  end
end
