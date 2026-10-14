require "test_helper"

class NumericScoreTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "rounds the final grade to one decimal, half up" do
    assert_equal BigDecimal("7.4"), NumericScore.round_final(7.37)
    assert_equal BigDecimal("8.1"), NumericScore.round_final(8.13)
    assert_equal BigDecimal("5.3"), NumericScore.round_final(5.25)
    assert_equal BigDecimal("6.9"), NumericScore.round_final(6.87)
    assert_equal BigDecimal("7.0"), NumericScore.round_final(6.95)
    assert_equal BigDecimal("10.0"), NumericScore.round_final(9.95)
  end

  test "leaves a blank score blank" do
    assert_nil NumericScore.round_final(nil)
    assert_nil NumericScore.round_final("")
  end
end
