require "test_helper"

class Activities::OnlineFormImporterTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "online-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "3º ano")
    @classroom_m = @professor.classrooms.create!(
      name: "3ª M",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @classroom_n = @professor.classrooms.create!(
      name: "3ª N",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @maria = @professor.students.create!(name: "Maria Silva")
    @joao = @professor.students.create!(name: "João Nunes")
    @other = @professor.students.create!(name: "Aluno Sem Envio")
    Enrollment.create!(professor: @professor, student: @maria, classroom: @classroom_m, enrolled_on: Date.current, status: "active")
    Enrollment.create!(professor: @professor, student: @joao, classroom: @classroom_n, enrolled_on: Date.current, status: "active")
    Enrollment.create!(professor: @professor, student: @other, classroom: @classroom_m, enrolled_on: Date.current, status: "active")
  end

  test "creates lesson activity scores and presence only for who submitted" do
    created = Activities::OnlineFormImporter.new(professor: @professor).import!(
      title: "Lista de exercícios",
      lesson_date: Date.new(2026, 10, 8),
      course_id: nil,
      items: [
        { classroom_id: @classroom_m.id, student_id: @maria.id, score: 9.0, submitted_at: Time.zone.parse("2026-10-08 22:29") },
        { classroom_id: @classroom_n.id, student_id: @joao.id, score: 8.0, submitted_at: Time.zone.parse("2026-10-09 11:00") }
      ]
    )

    assert_equal 2, created.size
    activity_m = created.find { |item| item[:classroom] == @classroom_m }[:activity]
    submission = ActivitySubmission.find_by(activity: activity_m, student: @maria)
    assert_equal 9.0, submission.score
    assert_equal Date.new(2026, 10, 8), submission.submitted_on

    lesson = created.find { |item| item[:classroom] == @classroom_m }[:lesson]
    enrollment = Enrollment.find_by(student: @maria, classroom: @classroom_m)
    attendance = AttendanceRecord.find_by(enrollment: enrollment, lesson: lesson)
    assert_equal "present", attendance.status

    other_enrollment = Enrollment.find_by(student: @other, classroom: @classroom_m)
    assert_nil AttendanceRecord.find_by(enrollment: other_enrollment, lesson: lesson)
    assert_nil ActivitySubmission.find_by(activity: activity_m, student: @other)
  end

  test "preview scales form points to a 0-10 score and matches classrooms" do
    rows = [
      Activities::OnlineFormParser::Row.new(name: "Maria Silva", classroom_label: "3ª Série M", raw_score: 18.0, submitted_at: Time.zone.parse("2026-10-08"), answers: Array.new(20, "A")),
      Activities::OnlineFormParser::Row.new(name: "João Nunes", classroom_label: "3ª Série N", raw_score: 20.0, submitted_at: Time.zone.parse("2026-10-09"), answers: Array.new(20, "B"))
    ]
    preview = Activities::OnlineFormPreview.new(professor: @professor, rows: rows)
    items = preview.items

    maria = items.find { |item| item[:name] == "Maria Silva" }
    assert_equal @classroom_m.id, maria[:classroom_id]
    assert_equal @maria.id, maria[:student_id]
    assert_equal 9.0, maria[:score]
  end

  test "second import reuses the activity and only adds students still without a grade" do
    date = Date.new(2026, 10, 8)
    first = Activities::OnlineFormImporter.new(professor: @professor).import!(
      title: "Lista de exercícios",
      lesson_date: date,
      course_id: nil,
      items: [
        { classroom_id: @classroom_m.id, student_id: @maria.id, score: 9.0, submitted_at: date }
      ]
    )
    activity = first.first[:activity]
    maria_id = ActivitySubmission.find_by!(activity: activity, student: @maria).id

    second = Activities::OnlineFormImporter.new(professor: @professor).import!(
      title: "Lista de exercícios",
      lesson_date: date,
      course_id: nil,
      items: [
        { classroom_id: @classroom_m.id, student_id: @maria.id, score: 1.0, submitted_at: date },
        { classroom_id: @classroom_m.id, student_id: @other.id, score: 7.5, submitted_at: date }
      ]
    )

    result = second.first
    assert_equal activity.id, result[:activity].id
    assert_equal 1, result[:count]
    assert_equal 1, result[:skipped]
    assert_equal 1, Lesson.where(professor: @professor, classroom: @classroom_m, lesson_date: date).count
    assert_equal 1, Activity.where(title: "Lista de exercícios").count

    maria = ActivitySubmission.find(maria_id)
    assert_equal 9.0, maria.score

    other = ActivitySubmission.find_by!(activity: activity, student: @other)
    assert_equal 7.5, other.score
  end

  test "preview marks students who already have a grade on that activity" do
    date = Date.new(2026, 10, 8)
    Activities::OnlineFormImporter.new(professor: @professor).import!(
      title: "Lista de exercícios",
      lesson_date: date,
      course_id: nil,
      items: [
        { classroom_id: @classroom_m.id, student_id: @maria.id, score: 9.0, submitted_at: date }
      ]
    )

    rows = [
      Activities::OnlineFormParser::Row.new(name: "Maria Silva", classroom_label: "3ª M", raw_score: 2.0, submitted_at: date.to_time, answers: ["A"]),
      Activities::OnlineFormParser::Row.new(name: "Aluno Sem Envio", classroom_label: "3ª M", raw_score: 10.0, submitted_at: date.to_time, answers: ["B"])
    ]
    preview = Activities::OnlineFormPreview.new(
      professor: @professor,
      rows: rows,
      title: "Lista de exercícios",
      lesson_date: date
    )
    items = preview.items

    maria = items.find { |item| item[:name] == "Maria Silva" }
    other = items.find { |item| item[:name] == "Aluno Sem Envio" }
    assert maria[:already_scored]
    assert_equal 9.0, maria[:score]
    refute other[:already_scored]
    assert_equal 10.0, other[:score]
  end

  test "treats Atividade online and Questionário online as the same activity" do
    date = Date.new(2026, 10, 19)
    first = Activities::OnlineFormImporter.new(professor: @professor).import!(
      title: "Questionário online",
      lesson_date: date,
      course_id: nil,
      items: [
        { classroom_id: @classroom_m.id, student_id: @maria.id, score: 8.5, submitted_at: date }
      ]
    )
    activity = first.first[:activity]

    second = Activities::OnlineFormImporter.new(professor: @professor).import!(
      title: "Atividade online",
      lesson_date: date,
      course_id: nil,
      items: [
        { classroom_id: @classroom_m.id, student_id: @other.id, score: 7.0, submitted_at: date }
      ]
    )

    assert_equal activity.id, second.first[:activity].id
    assert_equal 1, Activity.joins(:lesson).where(
      lessons: { classroom_id: @classroom_m.id }
    ).where("activities.title IN (?)", ["Questionário online", "Atividade online"]).count
    assert_equal 7.0, ActivitySubmission.find_by!(activity: activity, student: @other).score

    rows = [
      Activities::OnlineFormParser::Row.new(
        name: "Maria Silva",
        classroom_label: "3ª M",
        raw_score: 2.0,
        submitted_at: date.to_time,
        answers: ["A"]
      )
    ]
    preview = Activities::OnlineFormPreview.new(
      professor: @professor,
      rows: rows,
      title: "Atividade online",
      lesson_date: date
    )
    assert preview.items.first[:already_scored]
  end

  test "fills an existing classroom activity and matches abbreviated student names" do
    date = Date.new(2026, 10, 8)
    livramento = @professor.students.create!(name: "MARIA LIVRAMENTO SILVA C. DOS S.")
    Enrollment.create!(professor: @professor, student: livramento, classroom: @classroom_m, enrolled_on: date, status: "active")

    lesson = @professor.lessons.create!(
      classroom: @classroom_m,
      lesson_date: date,
      theme: "Lista de Exercícios",
      has_activity: true,
      siage_time_slot: "1º tempo",
      siage_class_mode: "Aula",
      siage_class_type: "Avulso",
      siage_period: Siage.period_for_date(date)
    )
    activity = lesson.create_activity!(
      title: "Lista de Exercícios",
      activity_type: "Lista de exercícios",
      due_date: Date.new(2026, 10, 13),
      maximum_score: 10,
      bimester: Siage.bimester_for_date(date),
      weight: 1
    )

    created = Activities::OnlineFormImporter.new(professor: @professor).import!(
      title: "Lista de Exercícios",
      lesson_date: date,
      course_id: nil,
      items: [
        { classroom_id: @classroom_m.id, student_id: livramento.id, score: 8.5, submitted_at: Time.zone.parse("2026-10-08 22:29") }
      ]
    )

    assert_equal activity.id, created.first[:activity].id
    submission = ActivitySubmission.find_by!(activity: activity, student: livramento)
    assert_equal 8.5, submission.score
    assert_equal Date.new(2026, 10, 8), submission.submitted_on
    refute submission.status == :not_delivered

    rows = [
      Activities::OnlineFormParser::Row.new(
        name: "Maria Livramento Silva Correia Dos Santos",
        classroom_label: "3ª Série M",
        raw_score: 17.0,
        submitted_at: Time.zone.parse("2026-10-08 22:29"),
        answers: ["A"]
      )
    ]
    preview = Activities::OnlineFormPreview.new(professor: @professor, rows: rows)
    item = preview.items.first
    assert_equal livramento.id, item[:student_id]
    assert_equal @classroom_m.id, item[:classroom_id]
  end
end
