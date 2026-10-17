require "test_helper"

class MaestroCommandInterpreterTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "ajuda lists the whatsapp commands" do
    professor = Professor.new(name: "Ana", email: "ana@maestro.test")
    reply = Maestro::CommandInterpreter.new(professor).reply("Ajuda")

    assert_match(/hoje/i, reply)
    assert_match(/status/i, reply)
    assert_match(/avisos/i, reply)
  end

  test "ignores ordinary questions" do
    professor = Professor.new(name: "Ana", email: "ana@maestro.test")
    assert_nil Maestro::CommandInterpreter.new(professor).reply("frequência da Maria na 2ª A")
  end

  test "status names the conversation brain" do
    professor = Professor.create!(
      name: "Ana Souza",
      email: "status-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )

    reply = Maestro::CommandInterpreter.new(professor).reply("status")

    assert_match(/Cérebro da conversa/, reply)
    assert_match(/#{Regexp.escape(Lira.brain_label)}/, reply)
  end
end
