require "test_helper"

class SiageExportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "siage-export-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "2º ano")
    @classroom = @professor.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.current,
      theme: "Célula",
      siage_time_slot: "1"
    )
  end

  test "downloads one spreadsheet for pending lessons across classrooms" do
    sign_in @professor
    other = @professor.classrooms.create!(
      name: "2ª G",
      school_year: 2026,
      grade_level: @professor.grade_levels.first,
      active: true
    )
    @professor.lessons.create!(
      classroom: other,
      lesson_date: Date.current,
      theme: "Outra",
      siage_time_slot: "2"
    )

    get siage_ledger_export_path

    assert_response :success
    assert_match "siage-pendentes-todas-as-turmas.csv", response.headers["Content-Disposition"]
    body = response.body.force_encoding("UTF-8")
    assert_includes body, "2ª SÉRIE F"
    assert_includes body, "2ª SÉRIE G"
  end
end
