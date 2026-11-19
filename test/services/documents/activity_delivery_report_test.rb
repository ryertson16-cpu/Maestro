require "test_helper"

class Documents::ActivityDeliveryReportTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "renders a pdf with student name, status and receipt date" do
    professor = Professor.create!(
      name: "Ana Souza",
      email: "activity-report-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = professor.grade_levels.create!(name: "2º ano")
    classroom = professor.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    student = professor.students.create!(name: "Maria Silva")
    Enrollment.create!(
      professor: professor,
      student: student,
      classroom: classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    lesson = professor.lessons.create!(
      classroom: classroom,
      lesson_date: Date.current,
      theme: "Celula",
      siage_time_slot: "1º tempo",
      has_activity: true
    )
    activity = lesson.create_activity!(
      title: "Lista genetica",
      activity_type: "Lista de exercícios",
      due_date: Date.current,
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
    ActivitySubmission.create!(
      activity: activity,
      student: student,
      professor: professor,
      score: 8,
      submitted_on: Date.current
    )

    pdf = Documents::ActivityDeliveryReport.new(
      professor: professor,
      classroom: classroom,
      activity: activity
    ).render

    text = PDF::Reader.new(StringIO.new(pdf)).pages.map(&:text).join("\n")
    assert_includes text, "Maria Silva"
    assert_includes text, "8,0"
    assert_includes text, "Situação"
    assert_includes text, "Aprovado"
  end

  test "prova report marks six or more as aprovado and the rest as recuperacao" do
    professor = Professor.create!(
      name: "Ana Souza",
      email: "activity-report-prova-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = professor.grade_levels.create!(name: "2º ano")
    classroom = professor.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    passed = professor.students.create!(name: "Ludimila Oliveira")
    failed = professor.students.create!(name: "Cayque Batista")
    [passed, failed].each do |student|
      Enrollment.create!(
        professor: professor,
        student: student,
        classroom: classroom,
        enrolled_on: Date.current,
        status: "active"
      )
    end
    lesson = professor.lessons.create!(
      classroom: classroom,
      lesson_date: Date.current,
      theme: "Quimica",
      siage_time_slot: "1º tempo",
      has_activity: true
    )
    activity = lesson.create_activity!(
      title: "Prova de Quimica",
      activity_type: "Prova",
      due_date: Date.current,
      bimester: 4,
      weight: 1,
      maximum_score: 10
    )
    question = activity.activity_questions.create!(
      prompt: "Qual e o resultado?",
      kind: "objective",
      position: 1,
      points: 1,
      correct_letter: "A",
      choices: [
        { "letter" => "A", "text" => "Certo" },
        { "letter" => "B", "text" => "Errado" },
        { "letter" => "C", "text" => "Outro" }
      ]
    )
    ActivitySubmission.create!(activity: activity, student: passed, professor: professor, score: 6, submitted_on: Date.current)
    ActivitySubmission.create!(activity: activity, student: failed, professor: professor, score: 5.9, submitted_on: Date.current)
    ActivityExamAssignment.create!(
      activity: activity,
      student: passed,
      slot: 2,
      item_order: [ question.id ],
      choice_maps: { question.id.to_s => { "C" => "A", "A" => "B", "B" => "C" } }
    )
    ActivityExamAssignment.create!(
      activity: activity,
      student: failed,
      slot: 3,
      item_order: [ question.id ],
      choice_maps: { question.id.to_s => { "B" => "A", "A" => "C", "C" => "B" } }
    )

    pdf = Documents::ActivityDeliveryReport.new(
      professor: professor,
      classroom: classroom,
      activity: activity
    ).render
    text = PDF::Reader.new(StringIO.new(pdf)).pages.map(&:text).join("\n")

    assert_includes text, "6,0"
    assert_includes text, "5,9"
    assert_includes text, "Aprovado"
    assert_includes text, "Recuperação"
    assert_includes text, "Tipo 2"
    assert_includes text, "Tipo 3"
    assert_includes text, "Gabaritos oficiais"
    assert_includes text, "Tipo 2: 1 C"
    assert_includes text, "Tipo 3: 1 B"
  end
end
