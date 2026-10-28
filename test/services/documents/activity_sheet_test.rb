require "test_helper"

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

  test "personalized exam prints the student name and card on its own page" do
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
    assert_includes last, "Q.1"
    assert_includes last, "3ª O"
    refute_match(/\bNota\b/, last)
  end
end
