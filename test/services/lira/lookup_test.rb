require "test_helper"

class Lira::LookupTest < ActiveSupport::TestCase
  ClassroomStub = Struct.new(:name, keyword_init: true)
  StudentStub = Struct.new(:name, keyword_init: true)

  test "picks 2ª H instead of 2ª I from a full question" do
    rooms = [
      ClassroomStub.new(name: "2ª H"),
      ClassroomStub.new(name: "2ª I")
    ]

    matches = Lira::Lookup.classrooms_from(
      "me traga as informações do aluno Breno da turma 2ª H",
      rooms
    )

    assert_equal ["2ª H"], matches.map(&:name)
  end

  test "keeps both homonyms when no classroom is given" do
    students = [
      StudentStub.new(name: "Breno da Silva"),
      StudentStub.new(name: "Breno Souza")
    ]

    matches = Lira::Lookup.students_from("cadê o Breno?", students)

    assert_equal ["Breno da Silva", "Breno Souza"], matches.map(&:name)
  end

  test "prefers the student whose surname was also cited" do
    students = [
      StudentStub.new(name: "Breno da Silva"),
      StudentStub.new(name: "Breno Souza")
    ]

    matches = Lira::Lookup.students_from("Breno Souza da 2ª I", students)

    assert_equal ["Breno Souza"], matches.map(&:name)
  end
end
