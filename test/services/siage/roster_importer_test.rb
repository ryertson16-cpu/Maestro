require "test_helper"

class Siage::RosterImporterTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "roster-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "preview merges SIAGE rows of the same class and matches existing students" do
    grade = @professor.grade_levels.create!(name: "2º ano", active: true)
    classroom = @professor.classrooms.create!(
      name: "2ª F",
      school_year: Date.current.year,
      grade_level: grade,
      active: true
    )
    @professor.courses.create!(name: "Ciências", knowledge_area: "ciencias_da_natureza")
    maria = @professor.students.create!(name: "Maria Silva")
    Enrollment.create!(
      professor: @professor,
      student: maria,
      classroom: classroom,
      enrolled_on: Date.current,
      status: "active"
    )

    preview = Siage::RosterPreview.new(
      professor: @professor,
      payload: {
        "classrooms" => [
          {
            "name" => "2ª SÉRIE F",
            "componente" => "Ciências",
            "turma_id" => "abc-123",
            "students" => [ { "name" => "Maria Silva" }, { "name" => "João Lima" } ]
          },
          {
            "name" => "2ª SÉRIE F",
            "componente" => "Matemática",
            "turma_id" => "def-456",
            "students" => [ { "name" => "Maria Silva" } ]
          }
        ]
      }
    ).as_json

    assert_equal 1, preview["classroom_count"]
    group = preview["classrooms"].first
    assert_equal "reuse", group["action"]
    assert_equal classroom.id, group["existing_classroom_id"]
    assert_equal 2, group["components"].size
    names = group["students"].map { |row| row["name"] }
    assert_includes names, "Maria Silva"
    assert_includes names, "João Lima"
    maria_row = group["students"].find { |row| row["name"] == "Maria Silva" }
    assert_equal "match", maria_row["action"]
    joao_row = group["students"].find { |row| row["name"] == "João Lima" }
    assert_equal "create", joao_row["action"]
  end

  test "importer creates missing classroom and student without deleting the old one" do
    grade = @professor.grade_levels.create!(name: "2º ano", active: true)
    old = @professor.classrooms.create!(
      name: "3ª A",
      school_year: Date.current.year,
      grade_level: grade,
      active: true
    )
    @professor.students.create!(name: "Carla Souza")

    preview = Siage::RosterPreview.new(
      professor: @professor,
      payload: {
        "classrooms" => [
          {
            "name" => "2ª SÉRIE F",
            "componente" => "História",
            "turma_id" => "uuid-1",
            "students" => [ { "name" => "Pedro Alves" } ]
          }
        ]
      }
    ).as_json

    result = Siage::RosterImporter.new(professor: @professor, preview: preview).call

    assert_equal 1, result.classrooms
    assert_equal 1, result.students
    assert @professor.classrooms.exists?(id: old.id)
    assert @professor.students.exists?(name: "Carla Souza")
    room = @professor.classrooms.find_by!(name: "2ª F")
    student = @professor.students.find_by!(name: "Pedro Alves")
    assert room.enrollments.exists?(student_id: student.id)
    assert_equal "uuid-1", @professor.siage_classroom_bindings.find_by!(classroom: room).siage_turma_id
    assert_equal "Ensino Médio", room.school_course.name
    assert room.school_course.courses.exists?(name: "História")
  end

  test "preview drops period rows and uses SIAGE course name" do
    preview = Siage::RosterPreview.new(
      professor: @professor,
      payload: {
        "classrooms" => [
          {
            "name" => "2ª SÉRIE H - INFORMÁTICA",
            "componente" => "Química",
            "qualificacao" => "INFORMÁTICA",
            "etapa" => "Curso técnico integrado (ensino médio integrado)",
            "curso" => "Informática",
            "turno" => "Manhã",
            "students" => [
              { "name" => "1º Período", "registration" => "10022026" },
              { "name" => "2º Período", "registration" => "24042026" },
              { "name" => "Ana Beatriz Costa" }
            ]
          }
        ]
      }
    ).as_json

    group = preview["classrooms"].first
    assert_equal "INFORMÁTICA", group["school_course"]
    assert_equal "morning", group["shift"]
    assert_equal [ "Ana Beatriz Costa" ], group["students"].map { |row| row["name"] }
  end
end
