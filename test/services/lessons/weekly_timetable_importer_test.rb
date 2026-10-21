require "test_helper"

class Lessons::WeeklyTimetableImporterTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      preferred_name: "Ryertson",
      email: "horario-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    @course = @professor.courses.create!(
      name: "Química",
      knowledge_area: "ciencias_da_natureza",
      active: true
    )
    grade = @professor.grade_levels.create!(name: "2º ano")
    %w[2ª\ H 2ª\ F 2ª\ I 2ª\ J 3ª\ K 3ª\ M 3ª\ N 3ª\ O 3ª\ P].each do |name|
      @professor.classrooms.create!(
        name: name,
        school_year: 2026,
        grade_level: grade,
        active: true
      )
    end
  end

  test "builds ryertson slots from the school week pdf" do
    path = Rails.root.join("test/fixtures/files/novo_horario.pdf")
    skip "PDF do horário não está nos fixtures" unless path.exist?

    upload = Rack::Test::UploadedFile.new(path, "application/pdf")
    result = Lessons::WeeklyTimetableImporter.new(professor: @professor, upload: upload).call

    assert result[:ok], result[:error]
    assert_operator result[:count], :>=, 3
    assert_operator @professor.timetable_entries.count, :>=, 3
    assert @professor.timetable_entries.joins(:classroom).exists?(["classrooms.name LIKE ?", "%H%"])
  end

  test "rejects a missing file" do
    result = Lessons::WeeklyTimetableImporter.new(professor: @professor, upload: nil).call

    assert_not result[:ok]
    assert_match(/PDF/, result[:error])
  end
end
