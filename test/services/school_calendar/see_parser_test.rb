require "test_helper"

class SchoolCalendar::SeeParserTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "reads the SEE Paraiba 2026 pdf grid" do
    path = Rails.root.join("test/fixtures/files/see_calendario_pb_2026.pdf")
    upload = Rack::Test::UploadedFile.new(path, "application/pdf")

    parsed = SchoolCalendar::SeeParser.new(upload).parse

    assert_equal 2026, parsed.year
    assert_equal "FM", parsed.cells[Date.new(2026, 1, 2)]
    assert_equal "FI", parsed.cells[Date.new(2026, 2, 2)]
    assert_equal "I1B", parsed.cells[Date.new(2026, 2, 10)]
    assert_equal "F", parsed.cells[Date.new(2026, 2, 17)]
    assert_equal "ODE", parsed.cells[Date.new(2026, 4, 7)]
    assert_equal "T1B", parsed.cells[Date.new(2026, 4, 23)]
    assert_equal "F", parsed.cells[Date.new(2026, 6, 4)]
    assert_equal "RE", parsed.cells[Date.new(2026, 6, 15)]
    assert_equal "T4B", parsed.cells[Date.new(2026, 12, 17)]
    assert_equal "RF", parsed.cells[Date.new(2026, 12, 18)]
    assert_equal "CF", parsed.cells[Date.new(2026, 12, 23)]
    assert_equal "F", parsed.cells[Date.new(2026, 12, 25)]
    assert_equal "Confraternização Universal", parsed.holiday_names[Date.new(2026, 1, 1)]
    assert_equal "São João", parsed.holiday_names[Date.new(2026, 6, 24)]
  end
end
