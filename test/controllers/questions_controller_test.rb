require "test_helper"

class QuestionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "questions-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in @professor
  end

  test "creates an objective question in the professor bank" do
    assert_difference -> { @professor.questions.count }, 1 do
      post questions_path, params: {
        question: {
          prompt: "Qual é o resultado de 2 + 2?",
          kind: "objective",
          correct_letter: "B",
          points: 1,
          choice_texts: ["3", "4", "5", "", ""]
        }
      }
    end

    assert_redirected_to questions_path
    question = @professor.questions.last
    assert_equal "B", question.correct_letter
    assert_equal 3, question.choice_pairs.size
  end

  test "rejects objective question without alternatives" do
    assert_no_difference -> { Question.count } do
      post questions_path, params: {
        question: {
          prompt: "Sem opções",
          kind: "objective",
          correct_letter: "A",
          points: 1,
          choice_texts: ["", "", "", "", ""]
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
