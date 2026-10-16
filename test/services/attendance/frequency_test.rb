require "test_helper"

class Attendance::FrequencyTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "late and justified count as presence" do
    records = [
      stub_record("present"),
      stub_record("late"),
      stub_record("justified"),
      stub_record("absent")
    ]

    assert_equal 75.0, Attendance::Frequency.percentage(records)
    assert_equal "regular", Attendance::Frequency.situation(75.0)
    assert_not Attendance::Frequency.below_minimum?(75.0)
    assert Attendance::Frequency.below_minimum?(74.9)
  end

  test "blank records have no percentage" do
    assert_nil Attendance::Frequency.percentage([])
    assert_equal "without_records", Attendance::Frequency.situation(nil)
  end

  private

  def stub_record(status)
    Struct.new(:status) do
      def absent?
        status == "absent"
      end

      def present?
        status == "present"
      end

      def justified?
        status == "justified"
      end

      def late?
        status == "late"
      end
    end.new(status)
  end
end
