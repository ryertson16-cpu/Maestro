require "test_helper"

class CorrectionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "qr-desk-#{SecureRandom.hex(4)}@maestro.test",
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
      lesson_date: Date.current,
      theme: "Célula",
      siage_time_slot: "1º tempo",
      has_activity: true
    )
    @activity = lesson.create_activity!(
      title: "Lista genética",
      activity_type: "Lista de exercícios",
      due_date: Date.current,
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
    Activities::Composer.new(@activity).add(
      @professor.questions.create!(
        prompt: "Mitocôndria produz?",
        kind: "objective",
        choices: [
          { "letter" => "A", "text" => "ATP" },
          { "letter" => "B", "text" => "DNA" }
        ],
        correct_letter: "A",
        points: 1
      )
    )
    sign_in @professor
  end

  test "desk page shows the activity qr and does not ask for the computer camera" do
    get corrections_path(classroom_id: @classroom.id, activity_id: @activity.id)

    assert_response :success
    assert_includes response.body, "Lista genética"
    assert_includes response.body, "Câmera"
    assert_includes response.body, "/g/#{@activity.reload.correction_token}"
    refute_includes response.body, "data-qr-video"
    refute_includes response.body, "Pedindo câmera"
  end

  test "token still opens the public gabarito" do
    @activity.ensure_correction_token!

    get corrections_path(t: @activity.correction_token)

    assert_redirected_to gabarito_path(@activity.correction_token)
  end
end
