require "test_helper"

class Maestro::LoginGreetingTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      email: "ryertson-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123",
      preferred_name: "Ryertson",
      sex: "male"
    )
  end

  test "morning greeting uses professor and preferred name" do
    travel_to Time.zone.parse("2026-10-10 08:15") do
      message = Maestro::LoginGreeting.new(@professor).message

      assert_equal "Bom dia, professor Ryertson. O que vamos fazer hoje?", message
    end
  end

  test "afternoon greeting uses professora when sex is female" do
    @professor.update!(sex: "female", preferred_name: "Ana")

    travel_to Time.zone.parse("2026-10-10 14:00") do
      message = Maestro::LoginGreeting.new(@professor).message

      assert_equal "Boa tarde, professora Ana. O que vamos fazer hoje?", message
    end
  end

  test "falls back to the first name when preferred name is blank" do
    @professor.update!(preferred_name: nil)

    travel_to Time.zone.parse("2026-10-10 20:10") do
      message = Maestro::LoginGreeting.new(@professor).message

      assert_equal "Boa noite, professor Ryertson. O que vamos fazer hoje?", message
    end
  end

  test "toast waits for the other login notices" do
    toast = Maestro::LoginGreeting.new(@professor).toast

    assert_equal "maestro", toast[:kind]
    assert_equal "Maestro", toast[:title]
    assert toast[:wait_for_others]
  end
end
