require "test_helper"

class GradeLevelSetupTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "nivel-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in @professor
  end

  test "creating a grade level returns to disciplinas not atividades" do
    post grade_levels_path, params: {
      grade_level: { name: "3º ano", active: true }
    }

    assert_redirected_to courses_path
    follow_redirect!
    assert_includes response.body, "Nível de ensino criado"
    assert_includes response.body, "3º ano"
  end
end
