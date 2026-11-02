require "test_helper"

class LessonsPackTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "lesson-pack-#{SecureRandom.hex(4)}@maestro.test",
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
      lesson_date: Date.new(2026, 10, 12),
      theme: "Célula",
      content: "Organelas",
      has_activity: false
    )
    sign_in @professor
  end

  test "index shows copy pack button and receive form" do
    get lessons_path(classroom_id: @classroom.id)

    assert_response :success
    assert_select "button", text: "Copiar pacote"
    assert_select "span.status-badge.status-pending", text: "Pendente"
    assert_select "h2", text: "Receber aulas de outro caderno"
    assert_select "form[action=?]", import_lessons_path
  end

  test "exports a lesson pack as json" do
    get export_lesson_path(@lesson, format: :json)

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "maestro.lesson.pack", payload["format"]
    assert_equal "Célula", payload["lessons"].first["theme"]
  end

  test "imports a pasted lesson pack" do
    other = Professor.create!(
      name: "Outro",
      email: "other-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    pack = Lessons::Packager.new(lessons: [ @lesson ]).to_pretty_json
    sign_in other

    assert_difference -> { other.lessons.count }, 1 do
      post import_lessons_path, params: { pack: pack }
    end

    assert_redirected_to lessons_path
    follow_redirect!
    assert_match(/aula\(s\) recebida/, response.body)
  end
end
