require "test_helper"

class SchoolCalendar::SeeImporterTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana",
      email: "see-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "applies SEE codes onto existing calendar kinds" do
    path = Rails.root.join("test/fixtures/files/see_calendario_pb_2026.pdf")
    upload = Rack::Test::UploadedFile.new(path, "application/pdf")

    result = SchoolCalendar::SeeImporter.new(professor: @professor, upload: upload).call

    assert result[:ok], result[:error]
    assert_equal 2026, result[:year]
    days = @professor.school_calendar_days.index_by(&:day)

    assert_equal "no_class", days[Date.new(2026, 1, 15)].kind
    assert_equal "planning", days[Date.new(2026, 2, 5)].kind
    assert_equal "milestone", days[Date.new(2026, 2, 10)].kind
    assert_equal "holiday", days[Date.new(2026, 6, 4)].kind
    assert_equal "Corpus Christi", days[Date.new(2026, 6, 4)].name
    assert_equal "no_class", days[Date.new(2026, 6, 24)].kind
    assert_equal "letivo", days[Date.new(2026, 4, 7)].kind
    assert_nil days[Date.new(2026, 3, 10)]
    assert days[Date.new(2026, 12, 18)].blocks_lessons?
    assert SchoolCalendar::YearView.new(year: 2026, marked_days: days.values).school_day?(Date.new(2026, 4, 7))
    refute SchoolCalendar::YearView.new(year: 2026, marked_days: days.values).school_day?(Date.new(2026, 1, 15))
  end
end
