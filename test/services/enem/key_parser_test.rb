require "test_helper"

class Enem::KeyParserTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "reads numbered official key lines" do
    text = (1..90).map { |index| "#{index} #{%w[A B C D E][(index - 1) % 5]}" }.join("\n")
    result = Enem::KeyParser.from_text(text)

    assert_equal 90, result.filled_count
    assert_equal "A", result.letters[0]
    assert_equal "B", result.letters[1]
    assert_equal "E", result.letters[89]
    assert_equal "pdf", result.source
  end

  test "falls back to a letter run" do
    run = ("ABCDE" * 18)
    result = Enem::KeyParser.from_text(run)

    assert_equal 90, result.filled_count
    assert_equal "C", result.letters[2]
  end
end
