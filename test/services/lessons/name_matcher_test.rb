require "test_helper"

class Lessons::NameMatcherTest < ActiveSupport::TestCase
  test "does not treat 2ª H and 2ª I as the same classroom" do
    text = "informações do aluno Breno da turma 2ª H"

    assert Lessons::NameMatcher.classroom_in_text?(text, "2ª H")
    refute Lessons::NameMatcher.classroom_in_text?(text, "2ª I")
    assert_equal ["2", "h"], Lessons::NameMatcher.serie_and_letter("2ª H")
    assert_equal ["2", "i"], Lessons::NameMatcher.serie_and_letter("2ª I")
  end

  test "matches classroom names that include the course after the letter" do
    text = "Breno da 2a H"

    assert Lessons::NameMatcher.classroom_in_text?(text, "2ª H Informática")
    refute Lessons::NameMatcher.classroom_in_text?(text, "2ª I Informática")
  end
end
