require "test_helper"

class Siage::RosterDiffTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "diff-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    @grade = @professor.grade_levels.create!(name: "2º ano", active: true)
    @sala_h = @professor.classrooms.create!(name: "2ª H", school_year: Date.current.year, grade_level: @grade, active: true)
    @sala_f = @professor.classrooms.create!(name: "2ª F", school_year: Date.current.year, grade_level: @grade, active: true)
    @aluno = @professor.students.create!(name: "Alerrandro Vitor da Silva Alves")
    Enrollment.create!(professor: @professor, student: @aluno, classroom: @sala_h, enrolled_on: Date.current, status: "active")
  end

  test "flags student whose SIAGE classroom differs from Maestro" do
    diff = Siage::RosterDiff.new(
      professor: @professor,
      payload: {
        "classrooms" => [
          {
            "name" => "2ª SÉRIE F",
            "componente" => "Ciências",
            "students" => [ { "name" => "Alerrandro Vitor da Silva Alves" } ]
          }
        ]
      }
    )

    assert_equal 1, diff.wrong_classroom.size
    row = diff.wrong_classroom.first
    assert_equal @sala_h, row.maestro_classroom
    assert_equal @sala_f, row.siage_classroom
    assert_equal "2ª F", row.siage_classroom_name
    assert_equal 0, diff.matched_count
  end
end
