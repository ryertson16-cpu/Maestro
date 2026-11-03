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

  test "does not enroll a student who already belongs to another classroom" do
    grade = @professor.grade_levels.create!(name: "2º ano", active: true)
    informatica = @professor.school_courses.create!(name: "INFORMÁTICA", active: true)
    agro = @professor.school_courses.create!(name: "AGROECOLOGIA", active: true)
    origem = @professor.classrooms.create!(
      name: "2ª H",
      school_year: Date.current.year,
      grade_level: grade,
      school_course: informatica,
      active: true
    )
    destino = @professor.classrooms.create!(
      name: "3ª K",
      school_year: Date.current.year,
      grade_level: grade,
      school_course: agro,
      active: true
    )
    aluno = @professor.students.create!(name: "Alerrandro Vitor da Silva Alves")
    Enrollment.create!(
      professor: @professor,
      student: aluno,
      classroom: origem,
      enrolled_on: Date.current,
      status: "active"
    )

    preview = Siage::RosterPreview.new(
      professor: @professor,
      payload: {
        "classrooms" => [
          {
            "name" => "3ª SÉRIE K - AGROECOLOGIA",
            "componente" => "Química",
            "qualificacao" => "AGROECOLOGIA",
            "students" => [ { "name" => "Alerrandro Vitor da Silva Alves" } ]
          }
        ]
      }
    ).as_json

    agro_group = preview["classrooms"].find { |row| row["name"] == "3ª K" }
    assert_empty agro_group["students"]

    Siage::RosterImporter.new(professor: @professor, preview: preview).call

    assert_equal [ origem.id ], aluno.enrollments.where(status: "active").pluck(:classroom_id)
    assert_not destino.enrollments.exists?(student_id: aluno.id)
  end

  test "keeps separate classrooms for different SIAGE qualifications" do
    preview = Siage::RosterPreview.new(
      professor: @professor,
      payload: {
        "classrooms" => [
          {
            "name" => "2ª SÉRIE H - INFORMÁTICA",
            "componente" => "Química",
            "qualificacao" => "INFORMÁTICA",
            "students" => [ { "name" => "Aluno Informatica Silva" } ]
          },
          {
            "name" => "3ª SÉRIE K - AGROECOLOGIA",
            "componente" => "Química",
            "qualificacao" => "AGROECOLOGIA",
            "students" => [ { "name" => "Aluno Agroecologia Souza" } ]
          }
        ]
      }
    ).as_json

    assert_equal 2, preview["classroom_count"]
    names = preview["classrooms"].map { |row| [ row["name"], row["school_course"] ] }
    assert_includes names, [ "2ª H", "INFORMÁTICA" ]
    assert_includes names, [ "3ª K", "AGROECOLOGIA" ]
  end
end
