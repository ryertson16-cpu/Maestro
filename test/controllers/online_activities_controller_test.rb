require "test_helper"

class OnlineActivitiesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "online-ctl-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "3º ano")
    @classroom = @professor.classrooms.create!(
      name: "3ª M",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @student = @professor.students.create!(name: "Maria Silva")
    Enrollment.create!(professor: @professor, student: @student, classroom: @classroom, enrolled_on: Date.current, status: "active")
    sign_in @professor
  end

  test "preview then create from csv spreadsheet" do
    file = Tempfile.new(["respostas", ".csv"])
    file.write(<<~CSV)
      Carimbo de data/hora,Pontuação,Nome do estudante,Turma,1) Q1
      08/10/2026 22:29:39,18.0,Maria Silva,3ª Série M,Alceno
    CSV
    file.close

    post preview_online_activity_path, params: {
      spreadsheet: Rack::Test::UploadedFile.new(file.path, "text/csv"),
      title: "Lista online"
    }

    assert_response :success
    assert_match "Maria Silva", response.body

    post online_activity_path, params: {
      title: "Lista online",
      lesson_date: "2026-10-08",
      items: [
        {
          include: "1",
          classroom_id: @classroom.id,
          student_id: @student.id,
          score: "9.0",
          submitted_at: "2026-10-08 22:29:39",
          name: "Maria Silva"
        }
      ]
    }

    assert_response :redirect
    activity = Activity.joins(:lesson).find_by(title: "Lista online", lessons: { classroom_id: @classroom.id })
    assert activity
    assert_redirected_to grade_levels_path(
      classroom_id: @classroom.id,
      activity_id: activity.id,
      bimester: activity.bimester,
      kind: "regular"
    )
    assert flash[:maestro_recap].present?
    assert_equal 9.0, activity.activity_submissions.find_by(student: @student).score
    assert_equal "present", AttendanceRecord.joins(:enrollment).find_by(enrollments: { student_id: @student.id }).status

    follow_redirect!
    assert_response :success
    assert_includes response.body, "toast-flashes"
    assert_includes response.body, "Pronto,"
  ensure
    file&.close
    file&.unlink
  end

  test "create without date shows the error toast and stays on the form" do
    post online_activity_path, params: {
      title: "Lista online",
      lesson_date: "",
      items: [
        {
          include: "1",
          classroom_id: @classroom.id,
          student_id: @student.id,
          score: "9.0",
          name: "Maria Silva"
        }
      ]
    }

    assert_redirected_to new_online_activity_path
    assert_match(/Não foi possível lançar a atividade online/, flash[:alert])
  end

end
