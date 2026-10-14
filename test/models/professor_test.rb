require "test_helper"

class ProfessorTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "normalizes cpf to 11 digits" do
    professor = Professor.new(
      name: "Ana",
      email: "cpf-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123",
      cpf: "529.982.247-25"
    )

    assert professor.valid?
    assert_equal "52998224725", professor.cpf
  end

  test "rejects short cpf" do
    professor = Professor.new(
      name: "Ana",
      email: "cpf-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123",
      cpf: "123"
    )

    assert_not professor.valid?
    assert professor.errors[:cpf].any?
  end
end
