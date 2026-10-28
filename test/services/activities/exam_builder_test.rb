require "test_helper"

class Activities::ExamBuilderTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "exam-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "3º ano")
    classroom = @professor.classrooms.create!(
      name: "3ª M",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    lesson = @professor.lessons.create!(
      classroom: classroom,
      lesson_date: Date.current,
      theme: "Função",
      has_activity: true,
      siage_time_slot: "1º tempo"
    )
    @activity = lesson.create_activity!(
      title: "Prova de funções",
      activity_type: "Prova",
      due_date: Date.current,
      bimester: 4,
      weight: 1,
      maximum_score: 10
    )
    @bank_item = @professor.questions.create!(
      prompt: "Qual é o vértice de uma parábola?",
      kind: "objective",
      choices: [
        { "letter" => "A", "text" => "ponto de máximo ou mínimo" },
        { "letter" => "B", "text" => "raiz" }
      ],
      correct_letter: "A",
      points: 1,
      tag: "função do 2º grau"
    )
  end

  test "pulls matching bank questions into the activity" do
    result = Activities::ExamBuilder.new(professor: @professor, activity: @activity).build!(
      topic: "função",
      quantity: 1
    )

    assert_equal 1, result.from_bank
    assert_equal 1, @activity.activity_questions.count
    assert_equal @bank_item.id, @activity.activity_questions.first.question_id
  end

  test "generates remaining objective items with a stubbed Lira" do
    brain = FakeExamBrain.new
    result = Activities::ExamBuilder.new(
      professor: @professor,
      activity: @activity,
      brain: brain
    ).build!(topic: "função do 2º grau", quantity: 2)

    assert_equal 1, result.from_bank
    assert_equal 1, result.generated
    assert_equal 2, @activity.activity_questions.count
    generated = @professor.questions.where.not(id: @bank_item.id).last
    assert_equal "A", generated.correct_letter
    assert generated.prompt.present?
  end

  class FakeExamBrain
    def extract_text(_prompt, system:)
      {
        "questions" => [
          {
            "prompt" => "O coeficiente a da função ax²+bx+c define a concavidade?",
            "choices" => {
              "A" => "Sim",
              "B" => "Não",
              "C" => "Só se b=0",
              "D" => "Só se c=0",
              "E" => "Nunca"
            },
            "correct" => "A"
          }
        ]
      }.to_json
    end
  end
end
