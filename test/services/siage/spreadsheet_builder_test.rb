require "test_helper"
require "csv"

class Siage::SpreadsheetBuilderTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "siage-csv-#{SecureRandom.hex(4)}@maestro.test",
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
      lesson_date: Date.new(2026, 10, 8),
      theme: "Célula",
      siage_time_slot: "1,2"
    )
  end

  test "csv includes maestro id token and origin" do
    csv = Siage::SpreadsheetBuilder.for_lesson(@lesson, origin: "http://127.0.0.1:3000")
    rows = CSV.parse(csv.delete_prefix("\uFEFF"), col_sep: "\t", headers: true)
    row = rows.first

    assert_equal "Id Maestro", rows.headers[6]
    assert_equal @lesson.id.to_s, row["Id Maestro"]
    assert_equal "http://127.0.0.1:3000", row["Maestro"]
    assert_equal @professor, Siage::ExtensionToken.professor_for(row["Token Maestro"])
  end

  test "json payload includes lesson id and token" do
    payload = Siage::PayloadBuilder.for_lesson(@lesson)

    assert_equal @lesson.id, payload[:lesson][:id]
    assert_equal @professor, Siage::ExtensionToken.professor_for(payload[:token])
  end

  test "grades payload skips blank scores and rec global" do
    student = @professor.students.create!(name: "Ana")
    Enrollment.create!(
      professor: @professor,
      classroom: @classroom,
      student: student,
      enrolled_on: Date.new(2026, 2, 2),
      status: "active"
    )

    payload = Siage::PayloadBuilder.for_grades(
      professor: @professor,
      classroom: @classroom,
      bimester: 3,
      origin: "http://127.0.0.1:3000"
    )

    assert_equal "grades", payload[:kind]
    assert_equal 3, payload[:bimester]
    assert_nil payload[:grades].first[:global_recovery]
    assert_nil payload[:grades].first[:period_average]
    assert payload[:grades].first[:units].all? { |unit| unit[:score].nil? }
  end

  test "one spreadsheet can include lessons from different classrooms" do
    grade = @professor.grade_levels.first
    other = @professor.classrooms.create!(
      name: "2ª G",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    other_lesson = @professor.lessons.create!(
      classroom: other,
      lesson_date: Date.new(2026, 10, 8),
      theme: "Outra",
      siage_time_slot: "1"
    )

    csv = Siage::SpreadsheetBuilder.for_lessons(
      professor: @professor,
      lessons: [ @lesson, other_lesson ],
      origin: "http://127.0.0.1:3000"
    )
    rows = CSV.parse(csv.delete_prefix("\uFEFF"), col_sep: "\t", headers: true)

    assert_equal 2, rows.size
    assert_includes rows.map { |row| row["Turma"] }, "2ª SÉRIE F"
    assert_includes rows.map { |row| row["Turma"] }, "2ª SÉRIE G"
  end

  test "expired token is rejected" do
    token = Siage::ExtensionToken.generate(@professor)

    travel_to 91.days.from_now do
      assert_nil Siage::ExtensionToken.professor_for(token)
    end
  end
end
