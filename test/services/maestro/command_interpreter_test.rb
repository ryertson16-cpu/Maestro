require "test_helper"

class MaestroCommandInterpreterTest < ActiveSupport::TestCase
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
end
