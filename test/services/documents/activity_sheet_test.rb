require "test_helper"
require "base64"

class Documents::ActivitySheetTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson",
      email: "sheet-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "3º ano")
    @classroom = @professor.classrooms.create!(
      name: "3ª O",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    course = @professor.courses.create!(name: "Química", knowledge_area: "ciencias_da_natureza")
    lesson = @professor.lessons.create!(
      classroom: @classroom,
      course: course,
      lesson_date: Date.current,
      theme: "Ligações",
      has_activity: true,
      siage_time_slot: "1"
    )
    @activity = lesson.create_activity!(
      title: "Prova de ligações",
      activity_type: "Prova",
      due_date: Date.current,
      bimester: 4,
      weight: 1,
      maximum_score: 10
    )
    @first = @activity.activity_questions.create!(
      position: 1,
      prompt: "Qual ligação?",
      kind: "objective",
      choices: [
        { "letter" => "A", "text" => "Iônica" },
        { "letter" => "B", "text" => "Metálica" }
      ],
      correct_letter: "A",
      points: 5
    )
    @second = @activity.activity_questions.create!(
      position: 2,
      prompt: "Explique.",
      kind: "discursive",
      points: 5
    )
    @third = @activity.activity_questions.create!(
      position: 3,
      prompt: "Polar?",
      kind: "objective",
      choices: [
        { "letter" => "A", "text" => "Sim" },
        { "letter" => "B", "text" => "Não" }
      ],
      correct_letter: "B",
      points: 5
    )
    @student = @professor.students.create!(name: "MARIA SILVA")
    Enrollment.create!(
      professor: @professor,
      student: @student,
      classroom: @classroom,
      enrolled_on: Date.current,
      status: "active"
    )
  end

  test "generic exam puts empty bubbles on a separate card after the questions" do
    pdf = Documents::ActivitySheet.new(
      professor: @professor,
      activity: @activity,
      correction_url: "http://example.test/g/token"
    ).render
    reader = PDF::Reader.new(StringIO.new(pdf))
    last = reader.pages.last.text

    assert_operator reader.page_count, :>=, 2
    assert_includes last, "Q.1"
    assert_includes last, "Q.3"
    refute_includes last, "Q.2"
    assert_includes last, "Aluno(a):"
    refute_match(/Discursiva/i, last)
    refute_match(/\bNota\b/, last)
  end

  test "personalized exam packs named answer cards after the questions" do
    Activities::ExamAssigner.new(@activity).ensure!([ @student ])
    pdf = Documents::ActivitySheet.new(
      professor: @professor,
      activity: @activity,
      students: [ @student ],
      student_url: ->(student) { "http://example.test/g/token/a/#{student.id}" }
    ).render
    reader = PDF::Reader.new(StringIO.new(pdf))
    last = reader.pages.last.text

    assert_operator reader.page_count, :>=, 2
    assert_includes last, "MARIA SILVA"
    assert_includes last, "CARTÃO-RESPOSTA"
    assert_includes last, "NOME DO ALUNO"
    assert_includes last, "3ª O"
    assert_includes last, "3º ano"
    refute_match(/\bNota\b/, last)
  end

  test "personalized exam prints the same source text before each student's questions" do
    @activity.update!(source_text: "Texto base da prova de quimica.")
    Activities::ExamAssigner.new(@activity).ensure!([ @student ])
    pdf = Documents::ActivitySheet.new(
      professor: @professor,
      activity: @activity,
      students: [ @student ],
      student_url: ->(student) { "http://example.test/g/token/a/#{student.id}" }
    ).render
    reader = PDF::Reader.new(StringIO.new(pdf))
    questions = reader.pages[0...-1].map(&:text).join("\n")

    assert_includes questions, "Texto"
    assert_includes questions, "Texto base da prova de quimica."
  end

  test "personalized exam prints the formatted source text" do
    @activity.update!(source_text: '<p style="text-align: center"><b>Agua</b> <i>fervente</i> <b><i>quente</i></b></p>')
    Activities::ExamAssigner.new(@activity).ensure!([ @student ])
    pdf = Documents::ActivitySheet.new(
      professor: @professor,
      activity: @activity,
      students: [ @student ],
      student_url: ->(student) { "http://example.test/g/token/a/#{student.id}" }
    ).render
    questions = PDF::Reader.new(StringIO.new(pdf)).pages[0...-1].map(&:text).join("\n")

    assert_includes questions, "Agua fervente quente"
    refute_includes questions, "<b>"
  end

  test "prints the bank image when the activity copy has none" do
    question = @professor.questions.create!(
      prompt: "Logo da IBM",
      kind: "objective",
      choices: [
        { "letter" => "A", "text" => "Listras" },
        { "letter" => "B", "text" => "Círculo" }
      ],
      correct_letter: "A",
      points: 1
    )
    png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
    question.image.attach(io: StringIO.new(png), filename: "ibm.png", content_type: "image/png")
    @activity.activity_questions.create!(
      question: question,
      position: 4,
      prompt: "O logotipo da IBM foi redesenhado.",
      kind: "objective",
      choices: question.choices,
      correct_letter: "A",
      points: 1
    )
    Activities::ExamAssigner.new(@activity).ensure!([ @student ])
    pdf = Documents::ActivitySheet.new(
      professor: @professor,
      activity: @activity.reload,
      students: [ @student ]
    ).render
    reader = PDF::Reader.new(StringIO.new(pdf))

    assert_includes reader.pages.map(&:text).join("\n"), "IBM"
    assert reader.pages.any? { |page| page.xobjects.any? }
  end

  test "student sheet places questions down the left column and then the right" do
    12.times do |index|
      number = format("%02d", index + 1)
      @activity.activity_questions.create!(
        position: 10 + index,
        prompt: "Questao #{number}. " + ("A liga quimica observada nesta amostra permanece estavel. " * 4),
        kind: "objective",
        choices: [
          { "letter" => "A", "text" => "Ionica" },
          { "letter" => "B", "text" => "Metalica" }
        ],
        correct_letter: "A",
        points: 1
      )
    end
    Activities::ExamAssigner.new(@activity).ensure!([ @student ])
    pdf = Documents::ActivitySheet.new(
      professor: @professor,
      activity: @activity.reload,
      students: [ @student ]
    ).render
    page = PDF::Reader.new(StringIO.new(pdf)).pages.first
    questions = page.runs.filter_map do |run|
      number = run.text[/\A(\d+)\. Questao /, 1]
      next unless number

      { number: number.to_i, x: run.x, y: run.y }
    end
    left = questions.select { |row| row[:x] < 160 }
    right = questions.select { |row| row[:x] > 220 }

    assert_operator left.size, :>=, 2
    assert_operator right.size, :>=, 1
    assert_operator right.map { |row| row[:number] }.min, :>, left.map { |row| row[:number] }.max
    ordered = left.sort_by { |row| -row[:y] }
    assert_equal ordered.map { |row| row[:number] }, ordered.map { |row| row[:number] }.sort
  end
end
