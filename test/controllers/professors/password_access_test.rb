require "test_helper"

class Professors::PasswordAccessTest < ActionDispatch::IntegrationTest
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      email: "acesso-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "wrong password stays on the login screen as a red alert" do
    post professor_session_path, params: {
      professor: { email: @professor.email, password: "senha-errada" }
    }
    follow_redirect! if response.redirect?

    assert_includes [ 200, 422 ], response.status
    assert_includes response.body, "E-mail ou senha inválidos."
    assert_includes response.body, "auth-alert"
    assert_not_includes response.body, '"message":"E-mail ou senha inválidos."'
  end

  test "registration asks for the password twice and rejects a mismatch" do
    email = "novo-#{SecureRandom.hex(4)}@maestro.test"

    get new_professor_registration_path
    assert_includes response.body, "Confirmar senha"

    post professor_registration_path, params: {
      professor: {
        name: "Ana Professora",
        email: email,
        password: "senha123",
        password_confirmation: "outra123"
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "não confere"
    assert_not Professor.exists?(email: email)
  end

  test "registration creates the account when the password is confirmed" do
    email = "novo-#{SecureRandom.hex(4)}@maestro.test"

    post professor_registration_path, params: {
      professor: {
        name: "Ana Professora",
        email: email,
        password: "senha123",
        password_confirmation: "senha123"
      }
    }

    assert_response :redirect
    assert Professor.exists?(email: email)
  end
end
