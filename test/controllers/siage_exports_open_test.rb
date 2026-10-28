require "test_helper"

class SiageExportsOpenTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "siage-open-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123",
      cpf: "52998224725",
      siage_password: "portal-siage"
    )
    sign_in @professor
  end

  test "opening siage does not queue lessons before the extension runs" do
    grade = @professor.grade_levels.create!(name: "2º ano")
    classroom = @professor.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @professor.lessons.create!(
      classroom: classroom,
      lesson_date: Date.current,
      theme: "Ácidos",
      has_activity: false,
      siage_time_slot: "1"
    )

    get siage_open_path

    assert_response :success
    assert_equal 0, SiageShipment.where(professor: @professor).count
  end

  test "open page exposes handoff json and open button" do
    get siage_open_path

    assert_response :success
    assert_includes response.body, "maestro-siage-handoff"
    assert_includes response.body, "data-siage-open"
    assert_includes response.body, "52998224725"
    assert_includes response.body, "portal-siage"
    assert_includes response.body, "Abrir SIAGE"
  end
end
