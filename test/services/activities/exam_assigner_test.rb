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

  test "the question pages hide the sheet number and the card prints it" do
    Activities::ExamAssigner.new(@activity).ensure!([ @ana, @bia ])
    pdf = Documents::ActivitySheet.new(
      professor: @professor,
      activity: @activity,
      students: [ @ana, @bia ],
      student_url: ->(student) { "http://example.test/g/token/a/#{student.id}" }
    ).render
    reader = PDF::Reader.new(StringIO.new(pdf))
    question = reader.pages.first.text
    cards = reader.pages.last.text

    assert_includes question, "Ana"
    assert_match(/1\.\s*Quem\?|Q\.1/, question)
    refute_match(/folha\s+\d+|variante|prova a\b/i, question)
    assert_match(/Folha\s+\d+/, cards)
    assert_operator reader.page_count, :>=, 3
  end

  test "a printed sheet keeps its order when the class or the version count changes" do
    @activity.update!(exam_version_count: 2)
    assigner = Activities::ExamAssigner.new(@activity)
    first = assigner.ensure!([ @ana, @bia ])
    ana = first.find { |row| row.student_id == @ana.id }
    @activity.update!(exam_sheets_locked: true, exam_version_count: 1)

    caio = @professor.students.create!(name: "Caio")
    Enrollment.create!(
      professor: @professor,
      student: caio,
      classroom: @classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    rows = Activities::ExamAssigner.new(@activity).ensure!([ @ana, @bia, caio ])
    ana_again = rows.find { |row| row.student_id == @ana.id }
    caio_row = rows.find { |row| row.student_id == caio.id }

    assert_equal ana.slot, ana_again.slot
    assert_equal ana.item_order, ana_again.item_order
    assert_equal ana.choice_maps, ana_again.choice_maps
    assert_equal ana.slot, caio_row.slot
    assert_equal ana.item_order, caio_row.item_order
  end

  test "cards already printed stay in two columns" do
    @activity.update!(exam_sheets_locked: true)

    assert_equal 2, @activity.printed_card_columns(10)
    assert_equal 1, Activities::BubbleGrid.columns_for(10)
  end

  test "ensure ignores duplicate students and extra choice letters" do
    @first.update!(
      choices: [
        { "letter" => "A", "text" => "Um" },
        { "letter" => "B", "text" => "Dois" },
        { "letter" => "C", "text" => "Tres" },
        { "letter" => "D", "text" => "Quatro" },
        { "letter" => "E", "text" => "Cinco" },
        { "letter" => "F", "text" => "Seis" }
      ]
    )

    rows = Activities::ExamAssigner.new(@activity).ensure!([ @ana, @ana, @bia ])

    assert_equal 2, rows.size
    assert_equal [ @ana.id, @bia.id ].sort, rows.map(&:student_id).sort
    map = rows.first.choice_maps[@first.id.to_s]
    assert_equal 5, map.size
    assert_equal %w[A B C D E], map.keys.sort
  end

  test "the chosen version count reshuffles questions and alternatives" do
    @activity.update!(exam_version_count: 1)
    one = Activities::ExamAssigner.new(@activity).ensure!([ @ana, @bia ])
    assert_equal [ 1 ], one.map(&:slot).uniq

    @activity.update!(exam_version_count: 2)
    rows = Activities::ExamAssigner.new(@activity).ensure!([ @ana, @bia ])
    assert_equal [ 1, 2 ], rows.map(&:slot).uniq.sort

    first, second = rows.sort_by(&:slot)
    assert_equal [ @first.id, @second.id ].sort, first.item_order.map(&:to_i).sort
    assert_equal [ @first.id, @second.id ].sort, second.item_order.map(&:to_i).sort
    map = first.choice_maps[@first.id.to_s]
    assert_equal %w[A B], map.keys.sort
    assert_equal %w[A B], map.values.sort
    refute_equal [ first.item_order, first.choice_maps ], [ second.item_order, second.choice_maps ]
  end

  test "gabarito uses one column when the questions fit and two when they do not" do
    assert_equal 1, Activities::BubbleGrid.columns_for(10)
    assert_equal 2, Activities::BubbleGrid.columns_for(30)
  end

  test "word file keeps the heading and a one column gabarito" do
    Activities::ExamAssigner.new(@activity).ensure!([ @ana ])
    binary = Documents::ActivityDocx.new(
      professor: @professor,
      activity: @activity,
      students: [ @ana ]
    ).render
    Zip::File.open_buffer(binary) do |zip|
      xml = zip.read("word/document.xml")
      assert_includes xml, "Prova"
      assert_includes xml, "Ana"
      assert_includes xml, "(A)"
      assert_includes xml, "(B)"
    end
  end
end
