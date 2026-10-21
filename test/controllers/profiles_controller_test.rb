require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      email: "perfil-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "settings includes the greeting form" do
    sign_in @professor
    get settings_path

    assert_response :success
    assert_includes response.body, "Como gostaria de ser chamado(a)?"
    assert_includes response.body, "Sexo"
  end

  test "saves cpf digits for SIAGE login" do
    sign_in @professor
    patch profile_path, params: {
      professor: { cpf: "123.456.789-09" }
    }

    assert_redirected_to settings_path
    assert_equal "12345678909", @professor.reload.cpf
  end

  test "saves siage password and keeps it when the field is blank" do
    sign_in @professor
    patch profile_path, params: {
      professor: { siage_password: "segredo-siage" }
    }

    assert_redirected_to settings_path
    assert_equal "segredo-siage", @professor.reload.siage_password

    patch profile_path, params: {
      professor: { preferred_name: "Ana", siage_password: "" }
    }

    assert_equal "segredo-siage", @professor.reload.siage_password
    assert_equal "Ana", @professor.preferred_name
  end

  test "saves preferred name and sex from settings" do
    sign_in @professor
    patch profile_path, params: {
      professor: {
        preferred_name: "Ryertson",
        sex: "male"
      }
    }

    assert_redirected_to settings_path
    @professor.reload
    assert_equal "Ryertson", @professor.preferred_name
    assert_equal "male", @professor.sex
  end

  test "login queues the purple maestro greeting after other toasts" do
    travel_to Time.zone.parse("2026-10-10 08:15") do
      post professor_session_path, params: {
        professor: { email: @professor.email, password: "password123" }
      }
      follow_redirect!

      assert_response :success
      assert_includes response.body, "Bom dia, professor Ryertson. O que vamos fazer hoje?"
      assert_includes response.body, '"kind":"maestro"'
      assert_includes response.body, '"wait_for_others":true'
      assert_includes response.body, "maestro-assistant"
    end
  end
end
