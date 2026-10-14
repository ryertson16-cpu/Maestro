require "test_helper"

class LessonTest < ActiveSupport::TestCase
  test "activity kind choices start with the worksheet types" do
    assert_equal(
      [
        "Lista de exercícios",
        "Atividade avaliativa",
        "Prática experimental"
      ],
      Lesson::ACTIVITY_KIND_CHOICES.first(3)
    )
    assert_includes Lesson::ACTIVITY_TYPES, "Atividade avaliativa"
    assert_includes Lesson::ACTIVITY_TYPES, "Lista de exercícios"
    assert_includes Lesson::ACTIVITY_TYPES, "Prova"
  end
end
