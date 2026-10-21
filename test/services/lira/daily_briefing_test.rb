require "test_helper"

class Lira::DailyBriefingTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "ana-lira-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "wake text greets the professor and covers today" do
    text = Lira::DailyBriefing.new(professor: @professor).wake_text

    assert_match(/Ana/, text)
    assert_match(/hoje/i, text)
    assert_match(/atraso não é falta/i, text)
  end

  test "oi uses the daily briefing instead of a generic hello" do
    toolkit = Lira::Toolkit.new(@professor)
    reply = Lira::LocalInterpreter.new(toolkit).reply("Oi")

    assert_match(/Ana/, reply)
    assert_match(/hoje/i, reply)
  end
end
