require "test_helper"

class Enem::AnswerMapTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "maps official second-day numbers 91-180 onto items 1-90" do
    raw = (91..180).index_with { |number| %w[A B C D E][(number - 91) % 5] }
    letters = Enem::AnswerMap.from(raw)

    assert_equal 90, letters.size
    assert_equal "A", letters[0]
    assert_equal "B", letters[1]
    assert_equal "E", letters[89]
  end

  test "keeps a 90-letter array as caderno order" do
    letters = Enem::AnswerMap.from(Array.new(90, "C"))

    assert_equal 90, letters.size
    assert letters.all? { |letter| letter == "C" }
  end
end
