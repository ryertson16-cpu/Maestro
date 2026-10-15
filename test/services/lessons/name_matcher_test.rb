require "test_helper"

class Lessons::NameMatcherTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

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

  test "matches a full form name to an abbreviated caderno name" do
    livramento = Student.new(name: "MARIA LIVRAMENTO SILVA C. DOS S.")
    beatriz = Student.new(name: "MARIA BEATRIZ VIEIRA CABRAL")
    eduarda = Student.new(name: "MARIA EDUARDA FERREIRA DA COSTA")
    students = [livramento, beatriz, eduarda]

    assert_equal livramento, Lessons::NameMatcher.match_student(
      "Maria Livramento Silva Correia Dos Santos",
      students
    )
    assert_equal beatriz, Lessons::NameMatcher.match_student(
      "Maria Beatriz Vieira Cabral",
      students
    )
    assert_nil Lessons::NameMatcher.match_student("Maria", students)
  end

  test "matches a short form name when the extra tokens belong to one student" do
    ana_costa = Student.new(name: "Ana Beatriz Costa")
    ana_laura = Student.new(name: "Ana Laura Dantas")

    assert_equal ana_costa, Lessons::NameMatcher.match_student("Ana Costa", [ana_costa, ana_laura])
  end
end
