require "test_helper"

class AttendanceRecordsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "diary-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in @professor
  end

  test "empty diary asks for a classroom instead of a lonely date form" do
    get attendance_records_path

    assert_response :success
    assert_includes response.body, "Diário de classe"
    assert_includes response.body, "Livro SIAGE"
    assert_includes response.body, "Calendário"
    assert_includes response.body, "Planos"
    assert_includes response.body, "Ajuda SIAGE"
    assert_includes response.body, "Nenhuma turma no caderno"
    refute_includes response.body, "Aulas deste dia"
    refute_includes response.body, "Trocar turma"
  end

  test "diary context has classroom and date together" do
    grade = @professor.grade_levels.create!(name: "2º ano")
    classroom = @professor.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )

    get attendance_records_path(classroom_id: classroom.id, attendance_date: "2026-10-09")

    assert_response :success
    assert_includes response.body, "Turma e data"
    assert_includes response.body, "2ª F"
    assert_includes response.body, "Carregar diário"
    assert_includes response.body, "Salvar frequência de todos os tempos"
    assert_includes response.body, "Histórico da turma"
    refute_includes response.body, "Aulas deste dia"
  end
end
