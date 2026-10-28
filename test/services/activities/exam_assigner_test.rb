require "test_helper"

class Activities::ExamAssignerTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "exam-assign-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "3º ano")
    @classroom = @professor.classrooms.create!(
      name: "3ª P",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.current,
      theme: "Química",
      has_activity: true,
      siage_time_slot: "1"
    )
    @activity = lesson.create_activity!(
      title: "Prova de Química",
      activity_type: "Prova",
      due_date: Date.current,
      bimester: 3,
      weight: 1,
      maximum_score: 10
    )
    @first = @activity.activity_questions.create!(
      position: 1,
      prompt: "Quem?",
      kind: "objective",
      choices: [
        { "letter" => "A", "text" => "Um" },
        { "letter" => "B", "text" => "Dois" }
      ],
      correct_letter: "B",
      points: 1
    )
    @second = @activity.activity_questions.create!(
      position: 2,
      prompt: "Onde?",
      kind: "objective",
      choices: [
        { "letter" => "A", "text" => "Aqui" },
        { "letter" => "B", "text" => "Ali" }
      ],
      correct_letter: "A",
      points: 1
    )
    @ana = @professor.students.create!(name: "Ana")
    @bia = @professor.students.create!(name: "Bia")
    [ @ana, @bia ].each do |student|
      Enrollment.create!(
        professor: @professor,
        student: student,
        classroom: @classroom,
        enrolled_on: Date.current,
        status: "active"
      )
    end
  end

  test "assigns hidden slots and scores the printed letter" do
    assigner = Activities::ExamAssigner.new(@activity)
    rows = assigner.ensure!([ @ana, @bia ])

    assert_equal 2, rows.size
    assert_equal [ 1, 2 ], rows.map(&:slot).uniq.sort

    ana_row = rows.find { |row| row.student_id == @ana.id }
    presented = assigner.presented_for(@ana)
    printed = presented.find { |item| item.item.id == @first.id }
    score = Activities::Grader.new(@activity, assignment: ana_row).score(
      { @first.id.to_s => printed.printed_correct, @second.id.to_s => presented.find { |item| item.item.id == @second.id }.printed_correct }
    )

    assert_equal 10.0, score
    refute_includes presented.map { |item| item.item.prompt }, "Variante"
  end

  test "student sheets do not print the slot label" do
    Activities::ExamAssigner.new(@activity).ensure!([ @ana, @bia ])
    pdf = Documents::ActivitySheet.new(
      professor: @professor,
      activity: @activity,
      students: [ @ana, @bia ],
      student_url: ->(student) { "http://example.test/g/token/a/#{student.id}" }
    ).render
    reader = PDF::Reader.new(StringIO.new(pdf))
    text = reader.pages.map(&:text).join(" ")

    assert_includes text, "Ana"
    assert_includes text, "Q.1"
    refute_match(/folha 1|variante|prova a\b/i, text)
    assert_operator reader.page_count, :>=, 4
  end
end
