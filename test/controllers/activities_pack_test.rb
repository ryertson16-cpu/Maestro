require "test_helper"

class ActivitiesPackTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "act-ctrl-#{SecureRandom.hex(4)}@maestro.test",
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
    lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.new(2026, 10, 12),
      theme: "Célula",
      has_activity: true
    )
    @activity = lesson.create_activity!(
      title: "Lista",
      activity_type: "Lista de exercícios",
      due_date: Date.new(2026, 10, 14),
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
    sign_in @professor
  end

  test "activities page shows copy pack button and receive form" do
    get grade_levels_path(classroom_id: @classroom.id, activity_id: @activity.id)

    assert_response :success
    assert_select "h2", text: "Receber atividades de outro caderno"
    assert_select "form[action=?]", import_activities_path
    assert_select "button", text: "Copiar pacote"
    assert_select "form.activity-classification-form a", count: 0
    assert_select ".activity-card-actions a", text: "Prova"
  end

  test "exports an activity pack as json" do
    get export_activity_path(@activity, format: :json)

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "maestro.activity.pack", payload["format"]
    assert_equal "Lista", payload["activities"].first["activity"]["title"]
  end

  test "imports a pasted activity pack" do
    other = Professor.create!(
      name: "Outro",
      email: "act-other-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    pack = Activities::Packager.new(activities: [ @activity ]).to_pretty_json
    sign_in other

    assert_difference -> { Activity.joins(:lesson).where(lessons: { professor_id: other.id }).count }, 1 do
      post import_activities_path, params: { pack: pack }
    end

    assert_redirected_to grade_levels_path
    follow_redirect!
    assert_match(/atividade\(s\) recebida/, response.body)
  end
end
