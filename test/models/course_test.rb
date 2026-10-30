require "test_helper"

class CourseTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana",
      email: "course-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "base tecnica stays hidden without a technical grade level" do
    @professor.grade_levels.create!(name: "Ensino Médio", active: true)

    refute Course.technical_base_available_for?(@professor)
    refute_includes Course.available_knowledge_areas_for(@professor).keys, "base_tecnica"
  end

  test "active level named tecnico or tecnica unlocks base tecnica" do
    @professor.grade_levels.create!(name: "1º Técnico", active: true)

    assert Course.technical_base_available_for?(@professor)
    assert_includes Course.available_knowledge_areas_for(@professor).keys, "base_tecnica"
  end

  test "inactive technical level does not unlock the area" do
    @professor.grade_levels.create!(name: "Educação Profissional Técnica", active: false)

    refute Course.technical_base_available_for?(@professor)
  end

  test "integral tecnica still counts as a technical level" do
    @professor.grade_levels.create!(name: "Integral Técnica", active: true)

    assert Course.technical_base_available_for?(@professor)
  end
end
