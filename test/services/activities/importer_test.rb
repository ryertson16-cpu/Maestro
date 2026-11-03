require "test_helper"

class Activities::ImporterTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @source = Professor.create!(
      name: "Ana",
      email: "act-src-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    @destination = Professor.create!(
      name: "Bia",
      email: "act-dst-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @source.grade_levels.create!(name: "2º ano")
    @classroom = @source.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    course = @source.courses.create!(
      name: "Ciências",
      knowledge_area: "ciencias_da_natureza",
      active: true
    )
    lesson = @source.lessons.create!(
      classroom: @classroom,
      course: course,
      lesson_date: Date.new(2026, 10, 12),
      theme: "Célula",
      content: "Organelas",
      has_activity: true
    )
    activity = lesson.create_activity!(
      title: "Lista",
      activity_type: "Lista de exercícios",
      due_date: Date.new(2026, 10, 14),
      bimester: 1,
      weight: 2,
      maximum_score: 10
    )
    activity.activity_questions.create!(
      position: 1,
      prompt: "O que é mitocôndria?",
      kind: "discursive",
      points: 2
    )
    @pack = Activities::Packager.new(activities: [ activity.reload ]).to_pretty_json
  end

  test "imports activity into another professor matching classroom by name" do
    grade = @destination.grade_levels.create!(name: "2º ano")
    @destination.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )

    result = Activities::Importer.new(professor: @destination, raw: @pack).call

    assert_equal 1, result.imported
    replica = Activity.joins(:lesson).find_by!(
      title: "Lista",
      lessons: { professor_id: @destination.id }
    )
    assert_equal "2ª F", replica.lesson.classroom.name
    assert_equal "O que é mitocôndria?", replica.activity_questions.first.prompt
    assert_equal 2, replica.weight
    assert_equal 0, replica.activity_submissions.count
  end

  test "skips when the same activity already exists in the classroom" do
    Activities::Importer.new(professor: @destination, raw: @pack).call
    result = Activities::Importer.new(professor: @destination, raw: @pack).call

    assert_equal 0, result.imported
    assert_equal 1, result.skipped
  end

  test "copies grades only when the student already exists by name" do
    student = @source.students.create!(name: "Maria Silva")
    Enrollment.create!(
      professor: @source,
      student: student,
      classroom: @classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    activity = Activity.joins(:lesson).find_by!(title: "Lista", lessons: { professor_id: @source.id })
    activity.activity_submissions.create!(
      professor: @source,
      student: student,
      score: 7.5,
      submitted_on: Date.new(2026, 10, 13)
    )
    pack = Activities::Packager.new(activities: [ activity.reload ]).to_pretty_json

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
      enrolled_on: Date.current,
      status: "active"
    )

    Activities::Importer.new(professor: @destination, raw: pack).call

    replica = Activity.joins(:lesson).find_by!(
      title: "Lista",
      lessons: { professor_id: @destination.id }
    )
    assert_equal 1, replica.activity_submissions.count
    assert_equal dest_student.id, replica.activity_submissions.first.student_id
    assert_equal 7.5, replica.activity_submissions.first.score.to_f
  end
end
