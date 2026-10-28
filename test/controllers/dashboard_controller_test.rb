require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      preferred_name: "Ryertson",
      email: "dash-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in @professor
  end

  test "home leads with today and keeps caderno shortcuts" do
    get root_path

    assert_response :success
    assert_includes response.body, "Olá,"
    assert_includes response.body, "Ryertson"
    assert_includes response.body, "Caderno de hoje"
    assert_includes response.body, "Áreas do caderno"
    assert_includes response.body, "Diário"
    assert_includes response.body, "Atividades"
    assert_includes response.body, "Monitoramento"
    assert_includes response.body, "Projetos"
    assert_includes response.body, "Turmas"
    assert_includes response.body, "Alunos"
    assert_includes response.body, "Disciplinas"
    assert_includes response.body, "Maestro"
    assert_includes response.body, "Configurações"
    assert_includes response.body, "sem chamada hoje"
    assert_includes response.body, "pendentes no SIAGE"
    assert_includes response.body, "alunos em alerta"
    refute_includes response.body, "Acesso rápido"
  end
end
