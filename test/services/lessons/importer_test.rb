require "test_helper"

class Lessons::ImporterTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @source = build_professor("source")
    @destination = build_professor("dest")
    grade = @source.grade_levels.create!(name: "2º ano")
    @classroom = @source.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @course = @source.courses.create!(
      name: "Ciências",
      knowledge_area: "ciencias_da_natureza"
    )
    @lesson = @source.lessons.create!(
      classroom: @classroom,
      course: @course,
      lesson_date: Date.new(2026, 10, 12),
      theme: "Célula",
      content: "Organelas",
      skills: "EF06CI05",
      siage_time_slot: "1º tempo",
      has_activity: true
    )
    activity = @lesson.create_activity!(
      title: "Lista",
      activity_type: "Lista de exercícios",
      due_date: Date.new(2026, 10, 14),
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
    activity.activity_questions.create!(
      position: 1,
      prompt: "O que é mitocôndria?",
      kind: "discursive",
      points: 2,
      bncc_skill: "EF06CI05"
    )
    @pack = Lessons::Packager.new(lessons: [ @lesson.reload ]).to_pretty_json
  end

  test "imports lesson into another professor matching classroom by name" do
    grade = @destination.grade_levels.create!(name: "2º ano")
    @destination.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )

    result = Lessons::Importer.new(professor: @destination, raw: @pack).call

    assert_equal 1, result.imported
    assert_equal 0, result.skipped
    replica = @destination.lessons.find_by!(theme: "Célula")
    refute_equal @lesson.id, replica.id
    assert_equal "2ª F", replica.classroom.name
    assert_equal "Ciências", replica.course.name
    assert_equal "Organelas", replica.content
    assert_equal "O que é mitocôndria?", replica.activity.activity_questions.first.prompt
    assert_equal 0, replica.activity.activity_submissions.count
    assert_equal 0, replica.siage_shipments.count
  end

  test "creates classroom and course when destination has neither" do
    result = Lessons::Importer.new(professor: @destination, raw: @pack).call

    assert_equal 1, result.imported
    replica = @destination.lessons.find_by!(theme: "Célula")
    assert_equal "2ª F", replica.classroom.name
    assert_equal 2026, replica.classroom.school_year
    assert_equal "2º ano", replica.classroom.grade_level.name
    assert_equal "ciencias_da_natureza", replica.course.knowledge_area
  end

  test "skips duplicate lesson in the same classroom" do
    Lessons::Importer.new(professor: @destination, raw: @pack).call
    result = Lessons::Importer.new(professor: @destination, raw: @pack).call

    assert_equal 0, result.imported
    assert_equal 1, result.skipped
    assert_equal 1, @destination.lessons.where(theme: "Célula").count
  end

  test "places pack into a chosen classroom" do
    grade = @destination.grade_levels.create!(name: "3º ano")
    other = @destination.classrooms.create!(
      name: "3ª A",
      school_year: 2026,
      grade_level: grade,
      active: true
    )

    result = Lessons::Importer.new(
      professor: @destination,
      raw: @pack,
      classroom: other
    ).call

    assert_equal 1, result.imported
    replica = @destination.lessons.find_by!(theme: "Célula")
    assert_equal other.id, replica.classroom_id
  end

  test "keeps SIAGE tag only when professor id and discipline already match" do
    SiageShipment.record!(
      professor: @source,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      status: "verified"
    )
    pack = Lessons::Packager.new(lessons: [ @lesson.reload ]).to_pretty_json
    other = @source.classrooms.create!(
      name: "2ª G",
      school_year: 2026,
      grade_level: @classroom.grade_level,
      active: true
    )

    result = Lessons::Importer.new(professor: @source, raw: pack, classroom: other).call

    assert_equal 1, result.imported
    replica = @source.lessons.find_by!(classroom: other, theme: "Célula")
    assert_equal "verified", replica.siage_shipments.newest.first.status
  end

  test "leaves lesson pending when professor id differs even with same course name" do
    SiageShipment.record!(
      professor: @source,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      status: "verified"
    )
    pack = Lessons::Packager.new(lessons: [ @lesson.reload ]).to_pretty_json
    @destination.courses.create!(name: "Ciências", knowledge_area: "ciencias_da_natureza")

    Lessons::Importer.new(professor: @destination, raw: pack).call

    replica = @destination.lessons.find_by!(theme: "Célula")
    assert_equal 0, replica.siage_shipments.count
  end

  test "leaves lesson pending when professor matches but discipline is new" do
    SiageShipment.record!(
      professor: @source,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      status: "verified"
    )
    payload = JSON.parse(Lessons::Packager.new(lessons: [ @lesson.reload ]).to_pretty_json)
    payload["lessons"][0]["course"] = {
      "name" => "História",
      "knowledge_area" => "ciencias_humanas"
    }
    other = @source.classrooms.create!(
      name: "2ª H",
      school_year: 2026,
      grade_level: @classroom.grade_level,
      active: true
    )

    Lessons::Importer.new(
      professor: @source,
      raw: payload.to_json,
      classroom: other
    ).call

    replica = @source.lessons.find_by!(classroom: other, theme: "Célula")
    assert_equal "História", replica.course.name
    assert_equal 0, replica.siage_shipments.count
  end

  test "copies attendance and grades onto students that already exist by name" do
    source_student = @source.students.create!(name: "Maria Silva")
    Enrollment.create!(
      professor: @source,
      student: source_student,
      classroom: @classroom,
      enrolled_on: Date.new(2026, 2, 1),
      status: "active"
    )
    AttendanceRecord.create!(
      professor: @source,
      enrollment: source_student.enrollments.first,
      lesson: @lesson,
      attendance_date: @lesson.lesson_date,
      status: "late",
      notes: "Entrou no 2º tempo"
    )
    @lesson.activity.activity_submissions.create!(
      professor: @source,
      student: source_student,
      score: 8.0,
      submitted_on: Date.new(2026, 10, 13),
      answers: { "1" => "Produz ATP" }
    )

    dest_grade = @destination.grade_levels.create!(name: "2º ano")
    dest_class = @destination.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: dest_grade,
      active: true
    )
    dest_student = @destination.students.create!(name: "Maria Silva")
    Enrollment.create!(
      professor: @destination,
      student: dest_student,
      classroom: dest_class,
      enrolled_on: Date.new(2026, 2, 1),
      status: "active"
    )

    pack = Lessons::Packager.new(lessons: [ @lesson.reload ]).to_pretty_json
    assert_no_difference -> { @destination.students.count } do
      Lessons::Importer.new(professor: @destination, raw: pack).call
    end

    replica = @destination.lessons.find_by!(theme: "Célula")
    record = replica.attendance_records.first
    assert_equal dest_student.id, record.student.id
    assert_equal "late", record.status
    assert_equal "Entrou no 2º tempo", record.notes
    submission = replica.activity.activity_submissions.first
    assert_equal dest_student.id, submission.student_id
    assert_in_delta 8.0, submission.score.to_f, 0.01
    assert_equal "Produz ATP", submission.answers["1"]
  end

  test "skips attendance and grades when the student name is not in the destination" do
    source_student = @source.students.create!(name: "João Ausente")
    Enrollment.create!(
      professor: @source,
      student: source_student,
      classroom: @classroom,
      enrolled_on: Date.new(2026, 2, 1),
      status: "active"
    )
    AttendanceRecord.create!(
      professor: @source,
      enrollment: source_student.enrollments.first,
      lesson: @lesson,
      attendance_date: @lesson.lesson_date,
      status: "absent"
    )

    pack = Lessons::Packager.new(lessons: [ @lesson.reload ]).to_pretty_json
    assert_no_difference -> { @destination.students.count } do
      Lessons::Importer.new(professor: @destination, raw: pack).call
    end

    replica = @destination.lessons.find_by!(theme: "Célula")
    assert_equal 0, replica.attendance_records.count
    assert_equal 0, replica.activity.activity_submissions.count
  end

  test "rejects json that is not a maestro lesson pack" do
    result = Lessons::Importer.new(
      professor: @destination,
      raw: { hello: "world" }.to_json
    ).call

    assert_equal 0, result.imported
    assert_includes result.errors.first, "não é de aula"
  end

  private

  def build_professor(prefix)
    Professor.create!(
      name: "Prof #{prefix}",
      email: "#{prefix}-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end
end
