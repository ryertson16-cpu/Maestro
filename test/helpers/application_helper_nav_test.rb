require "test_helper"

class ApplicationHelperNavTest < ActionView::TestCase
  include ApplicationHelper
  include Rails.application.routes.url_helpers
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "nav-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "dropdowns do not repeat the parent destination or the header SIAGE label" do
    groups = maestro_nav_groups
    labels = groups.flat_map { |group| group[:items].map { |item| item[:label] } }

    refute_includes labels, "SIAGE"
    refute_includes labels, "Turma atual"
    refute_includes labels, "Todas as turmas"
    refute_includes labels, "Chamada"
    refute_includes labels, "Entregas e notas"
    refute_includes labels, "Alertas"
    assert_includes labels, "Abrir SIAGE"
    assert_includes labels, "Envios SIAGE"
    assert_includes labels, "Alunos"
    assert_includes labels, "Projetos"
    assert_includes labels, "Banco de questões"
    assert_includes labels, "Corrigir por QR"
    assert_includes labels, "Atividade online"
    assert_includes labels, "Simulado ENEM"
    refute_includes labels, "Matrículas"
    refute_includes labels, "Disciplinas"
    refute_includes labels, "Médias e fechamento"

    groups.each do |group|
      child_hrefs = group[:items].map { |item| item[:href] }
      refute_includes child_hrefs, group[:href],
                      "#{group[:label]} repeats its own landing page in the dropdown"
    end
  end

  private

  def remembered_classroom
    nil
  end

  def current_professor
    @professor
  end
end
