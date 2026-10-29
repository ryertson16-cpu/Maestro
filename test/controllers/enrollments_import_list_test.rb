require "test_helper"

class EnrollmentsImportListTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana",
      email: "imp-#{SecureRandom.hex(4)}@maestro.test",
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
    sign_in @professor
  end

  test "downloads the classroom excel template" do
    get import_enrollments_template_path, params: { classroom_id: @classroom.id }

    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"].to_s)
    assert_match(/Maestro-alunos-2-f\.xlsx/, response.headers["Content-Disposition"].to_s)
    assert_equal "PK", response.body.b[0, 2]
  end

  test "workbook csv enrolls names and generates missing registration" do
    file = Tempfile.new(["modelo", ".csv"])
    file.write("Nome,Matrícula (opcional)\nZuleide Ramos,\n")
    file.rewind
    upload = Rack::Test::UploadedFile.new(file.path, "text/csv", original_filename: "lista.csv")

    post import_enrollments_workbook_path, params: {
      classroom_id: @classroom.id,
      file: upload
    }

    assert_redirected_to classroom_path(@classroom)
    student = @professor.students.find_by(name: "Zuleide Ramos")
    assert_match(/\AMAE2026[A-Z0-9]+\d{3}\z/, student.registration_number)
  ensure
    file.close!
  end

  test "paste list enrolls names in the chosen classroom" do
    post import_list_enrollments_path, params: {
      classroom_id: @classroom.id,
      list: "Ana Beatriz\nCarlos Lima"
    }

    assert_redirected_to classroom_path(@classroom)
    assert_equal 2, @classroom.students.count
  end
end
