require "test_helper"

class Professors::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      email: "social-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "google callback signs in by email" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "g-callback",
      info: { email: @professor.email, name: @professor.name },
      extra: { raw_info: { "email_verified" => true } }
    )

    get professor_google_oauth2_omniauth_callback_path

    assert_redirected_to root_path
    follow_redirect!
    assert_equal @professor.id, request.env["warden"].user(:professor)&.id
  ensure
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  test "unconfigured provider explains the missing keys" do
    post oauth_unconfigured_path, params: { provider: "instagram" }

    assert_redirected_to new_professor_session_path
    follow_redirect!
    assert_includes response.body, "ainda não está configurado"
  end
end
