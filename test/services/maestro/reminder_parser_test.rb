require "test_helper"

class Maestro::ReminderParserTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "parses tomorrow afternoon reminder" do
    travel_to Time.zone.parse("2026-10-09 08:15") do
      parsed = Maestro::ReminderParser.new(
        "Me lembra de buscar a encomenda amanhã às 17h"
      ).parse

      assert_nil parsed.error
      assert_equal "Buscar a encomenda", parsed.title
      assert_equal Time.zone.parse("2026-10-10 17:00"), parsed.remind_at
    end
  end

  test "parses next weekday" do
    travel_to Time.zone.parse("2026-10-10 09:00") do
      parsed = Maestro::ReminderParser.new(
        "me lembra da reunião de pais na terça às 19h"
      ).parse

      assert_equal "Reunião de pais", parsed.title
      assert_equal Time.zone.parse("2026-10-13 19:00"), parsed.remind_at
    end
  end

  test "rejects a time that already passed" do
    travel_to Time.zone.parse("2026-10-10 20:00") do
      parsed = Maestro::ReminderParser.new("me lembra hoje às 8h").parse

      assert_equal "Esse horário já passou. Escolha outro.", parsed.error
    end
  end

  test "does not treat a school period as a clock time" do
    travel_to Time.zone.parse("2026-10-10 09:00") do
      parsed = Maestro::ReminderParser.new(
        "me lembra de lançar a chamada da 2ª F amanhã no 1º tempo",
        forced: true
      ).parse

      assert_equal "Lançar a chamada da 2ª F no 1º tempo", parsed.title
      assert_equal Time.zone.parse("2026-10-11 08:00"), parsed.remind_at
    end
  end
end
