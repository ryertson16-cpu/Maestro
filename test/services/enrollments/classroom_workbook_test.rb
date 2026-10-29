require "test_helper"

class Enrollments::ClassroomWorkbookTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana",
      email: "wb-#{SecureRandom.hex(4)}@maestro.test",
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

  test "template is an excel file with the name and registration columns" do
    bytes = Enrollments::ClassroomWorkbook.bytes(@classroom)

    assert_equal "PK", bytes[0, 2]
    assert_match(/Maestro-alunos-2-f\.xlsx/, Enrollments::ClassroomWorkbook.filename(@classroom))
  end

  test "csv of the model columns becomes student rows" do
    file = Tempfile.new(["modelo", ".csv"])
    file.write("Nome,Matrícula (opcional)\nMaria Silva,\nCarlos Lima,2026123\n")
    file.rewind

    upload = Rack::Test::UploadedFile.new(file.path, "text/csv", original_filename: "Maestro-alunos.csv")
    rows = Enrollments::ClassroomWorkbook.rows_from(upload)

    assert_equal "Maria Silva", rows.first[:name]
    assert_nil rows.first[:registration_number]
    assert_equal "2026123", rows.last[:registration_number]
  ensure
    file.close!
  end
end
