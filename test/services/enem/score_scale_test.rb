require "test_helper"

class Enem::ScoreScaleTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "maps hit bands onto note bands" do
    assert_equal 0.0, Enem::ScoreScale.note_for(0)
    assert_equal 0.9, Enem::ScoreScale.note_for(8)
    assert_equal 2.0, Enem::ScoreScale.note_for(18)
    assert_equal 6.0, Enem::ScoreScale.note_for(45)
    assert_equal 6.9, Enem::ScoreScale.note_for(53)
    assert_equal 9.5, Enem::ScoreScale.note_for(81)
    assert_equal 10.0, Enem::ScoreScale.note_for(90)
  end

  test "skips the 5 point band so half the items already yield the caderno average" do
    notes = (0..90).map { |hits| Enem::ScoreScale.note_for(hits) }
    refute notes.any? { |note| note >= 5.0 && note < 6.0 }
    assert notes.any? { |note| note == 6.0 }
  end
end
