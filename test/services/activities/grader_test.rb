require "test_helper"

class Activities::GraderTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "grader-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "2º ano")
    classroom = @professor.classrooms.create!(
      name: "2ª Q",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @lesson = @professor.lessons.create!(
      classroom: classroom,
      lesson_date: Date.current,
      theme: "Genética",
      siage_time_slot: "1"
    )
    @activity = @lesson.create_activity!(
      title: "Prova objetiva",
      activity_type: "Prova",
      due_date: Date.current,
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
  end

  test "scores objective answers against the assembled key" do
    first = @activity.activity_questions.create!(
      position: 1,
      prompt: "Quem?",
      kind: "objective",
      choices: [{ "letter" => "A", "text" => "Um" }, { "letter" => "B", "text" => "Dois" }],
      correct_letter: "B",
      points: 1
    )
    second = @activity.activity_questions.create!(
      position: 2,
      prompt: "Onde?",
      kind: "objective",
      choices: [{ "letter" => "A", "text" => "Aqui" }, { "letter" => "B", "text" => "Lá" }],
      correct_letter: "A",
      points: 1
    )

    score = Activities::Grader.new(@activity).score(
      first.id.to_s => "B",
      second.id.to_s => "B"
    )

    assert_equal 5.0, score
  end
end
