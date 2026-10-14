require "test_helper"

class Maestro::ActionRecapTest < ActiveSupport::TestCase
  ClassroomLike = Struct.new(:name, :id, keyword_init: true)
  LessonLike = Struct.new(:siage_time_slot, :lesson_date, :theme, :classroom, :classroom_id, keyword_init: true)
  ActivityLike = Struct.new(:title, :bimester, keyword_init: true)

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      email: "recap-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123",
      preferred_name: "Ryertson",
      sex: "male"
    )
    @classroom = ClassroomLike.new(name: "2ª F", id: 11)
    @lesson = LessonLike.new(
      siage_time_slot: "2º tempo",
      lesson_date: Date.new(2026, 10, 9),
      theme: "Classificação do Carbono",
      classroom: @classroom,
      classroom_id: 11
    )
  end

  test "attendance recap greets the professor and bolds the keywords" do
    toast = Maestro::ActionRecap.new(@professor).attendance(
      lesson: @lesson,
      classroom: @classroom,
      exporting: false
    )

    assert_equal "maestro", toast[:kind]
    assert_equal "Pronto, professor Ryertson. Ficou no caderno.", toast[:message]
    assert_equal "Livro SIAGE", toast[:action]
    refute toast[:wait_for_others]

    line = toast[:lines].first
    assert_equal "Chamada", line[:label]
    texts = line[:parts].select { |part| part[:bold] }.map { |part| part[:text] }
    assert_equal [ "2ª F", "2º tempo", "4º bimestre" ], texts
  end

  test "exporting attendance adds a SIAGE line" do
    toast = Maestro::ActionRecap.new(@professor).attendance(
      lesson: @lesson,
      classroom: @classroom,
      exporting: true
    )

    assert_equal [ "Chamada", "SIAGE" ], toast[:lines].map { |line| line[:label] }
  end

  test "lesson recap bolds classroom, topic and bimester" do
    toast = Maestro::ActionRecap.new(@professor).lesson_saved(@lesson)

    line = toast[:lines].first
    assert_equal "Aula", line[:label]
    assert_equal "Lançar frequência", toast[:action]
    texts = line[:parts].select { |part| part[:bold] }.map { |part| part[:text] }
    assert_equal [ "2ª F", "Classificação do Carbono", "4º bimestre" ], texts
  end

  test "grades recap uses the activity title" do
    activity = ActivityLike.new(title: "Prova de Química", bimester: 4)
    toast = Maestro::ActionRecap.new(@professor).grades(activity, classroom: @classroom)

    line = toast[:lines].first
    assert_equal "Notas", line[:label]
    texts = line[:parts].select { |part| part[:bold] }.map { |part| part[:text] }
    assert_equal [ "Prova de Química", "2ª F", "4º bimestre" ], texts
  end

  test "recovery recap uses professora when sex is female" do
    @professor.update!(sex: "female", preferred_name: "Ana")
    toast = Maestro::ActionRecap.new(@professor).recovery(
      classroom: @classroom,
      bimester: 4,
      student_name: "João"
    )

    assert_equal "Pronto, professora Ana. Ficou no caderno.", toast[:message]
    assert_includes toast[:lines].first[:parts].map { |part| part[:text] }, "João"
  end
end
