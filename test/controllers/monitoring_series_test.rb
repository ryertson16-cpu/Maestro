require "test_helper"

class MonitoringSeriesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana",
      email: "mon-series-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    @level = @professor.grade_levels.create!(name: "3º ano")
    @classroom = @professor.classrooms.create!(
      name: "3ª D",
      school_year: 2026,
      grade_level: @level,
      active: true
    )
    sign_in @professor
  end

  test "monitoring shows the series desk" do
    get monitoring_path(grade_level_id: @level.id, bimester: 3)

    assert_response :success
    assert_includes response.body, "As turmas neste bimestre"
    assert_includes response.body, "Plano de ação do bimestre"
    assert_includes response.body, "3ª D"
  end

  test "professor adds and downloads an action plan" do
    post bimester_actions_path, params: {
      grade_level_id: @level.id,
      bimester: 3,
      bimester_action: {
        title: "Aula de reforço na 3ª D",
        audience: "Alunos abaixo de 6",
        due_on: Date.current + 7
      }
    }

    assert_redirected_to monitoring_path(grade_level_id: @level.id, bimester: 3)
    assert_equal 1, @professor.bimester_actions.count

    get monitoring_plan_path(grade_level_id: @level.id, bimester: 3)

    assert_response :success
    assert_match "application/pdf", response.media_type
  end

  test "saves a series goal" do
    patch monitoring_series_goal_path, params: {
      grade_level_id: @level.id,
      bimester: 3,
      target_average: "7,5"
    }

    setting = SeriesBimesterSetting.find_by!(professor: @professor, grade_level: @level, bimester: 3)
    assert_equal 7.5, setting.target_average.to_f
  end
end
