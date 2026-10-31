require "test_helper"
require "chunky_png"

class Activities::CardMarkTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana",
      email: "mark-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "2º ano")
    classroom = @professor.classrooms.create!(name: "2ª M", school_year: 2026, grade_level: grade, active: true)
    lesson = @professor.lessons.create!(
      classroom: classroom,
      lesson_date: Date.current,
      theme: "Função",
      has_activity: true,
      siage_time_slot: "1"
    )
    @activity = lesson.create_activity!(
      title: "Prova",
      activity_type: "Prova",
      due_date: Date.current,
      bimester: 4,
      weight: 1,
      maximum_score: 10
    )
    question = @professor.questions.create!(
      prompt: "2+2?",
      kind: "objective",
      choices: [
        { "letter" => "A", "text" => "4" },
        { "letter" => "B", "text" => "3" }
      ],
      correct_letter: "A",
      points: 1
    )
    @item = Activities::Composer.new(@activity).add(question)
    @student = @professor.students.create!(name: "Maria")
    Enrollment.create!(professor: @professor, student: @student, classroom: classroom, enrolled_on: Date.current, status: "active")
  end

  test "green on the correct bubble when the student filled it" do
    marks = Activities::CardMark.marks(
      activity: @activity,
      student: @student,
      position_answers: { "1" => "A" },
      bubbles: { "1" => { "A" => [ 0.5, 0.4 ], "B" => [ 0.7, 0.4 ] } }
    )

    assert_equal 1, marks.size
    assert_equal :hit, marks.first[:kind]
    assert_equal "A", marks.first[:letter]
  end

  test "red on the empty correct bubble when the student missed it" do
    marks = Activities::CardMark.marks(
      activity: @activity,
      student: @student,
      position_answers: { "1" => "B" },
      bubbles: { "1" => { "A" => [ 0.5, 0.4 ], "B" => [ 0.7, 0.4 ] } }
    )

    assert_equal :miss, marks.first[:kind]
    assert_in_delta 0.5, marks.first[:x]
  end

  test "blue on the correct bubble when the question is blank" do
    marks = Activities::CardMark.marks(
      activity: @activity,
      student: @student,
      position_answers: {},
      bubbles: { "1" => { "A" => [ 0.2, 0.3 ] } }
    )

    assert_equal :blank, marks.first[:kind]
  end

  test "overlay paints a green circle on the photo" do
    path = Rails.root.join("tmp/card-mark-#{SecureRandom.hex(4)}.png").to_s
    ChunkyPNG::Image.new(80, 80, ChunkyPNG::Color::WHITE).save(path)
    file = Activities::CardMarkOverlay.render(
      path,
      [ { x: 0.5, y: 0.5, kind: :hit } ]
    )

    image = ChunkyPNG::Image.from_file(file.path)
    pixel = image[40, 40]
    assert_operator ChunkyPNG::Color.g(pixel), :>, 100
    assert_operator ChunkyPNG::Color.g(pixel), :>, ChunkyPNG::Color.r(pixel)
  ensure
    File.delete(path) if path && File.exist?(path)
    file&.close
    file&.unlink
  end
end
