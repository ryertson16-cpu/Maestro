require "test_helper"

class Monitoring::SeriesReportTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana",
      email: "series-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    @level = @professor.grade_levels.create!(name: "3º ano")
    @room_a = classroom!("3ª A")
    @room_d = classroom!("3ª D")
    @student_a = enroll!(@room_a, "Beatriz")
    @student_d = enroll!(@room_d, "Kaique")
  end

  test "cards show bimester average, students below six and lagging classroom" do
    score!(@room_a, @student_a, 8, title: "Lista")
    score!(@room_d, @student_d, 5, title: "Lista D")

    report = Monitoring::SeriesReport.new(professor: @professor, grade_level: @level, bimester: 3)
    cards = report.classroom_cards.index_by { |card| card.classroom.id }

    assert_equal 8.0, cards[@room_a.id].average
    assert_equal 0, cards[@room_a.id].below_count
    assert_equal 5.0, cards[@room_d.id].average
    assert_equal 1, cards[@room_d.id].below_count
    assert cards[@room_d.id].attention
    refute cards[@room_a.id].attention
    assert_equal 1, report.below_total
    assert_equal "Kaique", report.students_in_need.first.student.name
  end

  test "delta uses the last two exams" do
    first = score!(@room_a, @student_a, 7, title: "Prova 1", type: "Prova", date: Date.new(2026, 8, 10))
    score!(@room_a, @student_a, 7.4, title: "Prova 2", type: "Prova", date: Date.new(2026, 9, 10))

    report = Monitoring::SeriesReport.new(professor: @professor, grade_level: @level, bimester: first.bimester)
    card = report.classroom_cards.find { |row| row.classroom.id == @room_a.id }

    assert_equal 0.4, card.delta
  end

  test "weakest topic uses objective item misses when answers exist" do
    activity = score!(@room_d, @student_d, 4, title: "Prova de combinatoria", type: "Prova")
    item = activity.activity_questions.create!(
      prompt: "Arranjos e combinacoes",
      kind: "objective",
      position: 1,
      points: 1,
      correct_letter: "A",
      choices: [ { "letter" => "A", "text" => "certo" }, { "letter" => "B", "text" => "errado" } ]
    )
    submission = ActivitySubmission.find_by!(activity: activity, student: @student_d)
    submission.update!(answers: { item.id.to_s => "B" })

    report = Monitoring::SeriesReport.new(professor: @professor, grade_level: @level, bimester: activity.bimester)
    topic = report.attention_points.find { |point| point.kind == :topic }

    assert_includes topic.title, "Arranjos"
  end

  private

  def classroom!(name)
    @professor.classrooms.create!(
      name: name,
      school_year: 2026,
      grade_level: @level,
      active: true
    )
  end

  def enroll!(classroom, name)
    student = @professor.students.create!(name: name)
    Enrollment.create!(
      professor: @professor,
      student: student,
      classroom: classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    student
  end

  def score!(classroom, student, value, title:, type: "Lista de exercícios", date: Date.new(2026, 8, 20))
    lesson = @professor.lessons.create!(
      classroom: classroom,
      lesson_date: date,
      theme: title,
      has_activity: true,
      siage_time_slot: "1º tempo"
    )
    activity = lesson.create_activity!(
      title: title,
      activity_type: type,
      due_date: date,
      bimester: 3,
      weight: 1,
      maximum_score: 10
    )
    ActivitySubmission.create!(
      professor: @professor,
      activity: activity,
      student: student,
      score: value,
      submitted_on: date
    )
    activity
  end
end
