require "test_helper"
require "base64"

class Lessons::PackagerTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "pack-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "2º ano")
    @classroom = @professor.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      shift: "morning",
      active: true
    )
    @course = @professor.courses.create!(
      name: "Ciências",
      knowledge_area: "ciencias_da_natureza",
      active: true
    )
    @lesson = @professor.lessons.create!(
      classroom: @classroom,
      course: @course,
      lesson_date: Date.new(2026, 10, 12),
      theme: "Célula",
      content: "Organelas",
      objective: "Identificar organelas",
      methodology: "Aula expositiva",
      skills: "EF06CI05",
      siage_time_slot: "1º tempo",
      has_activity: true
    )
    @activity = @lesson.create_activity!(
      title: "Lista",
      activity_type: "Lista de exercícios",
      due_date: Date.new(2026, 10, 14),
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
    question = @activity.activity_questions.create!(
      position: 1,
      prompt: "O que é mitocôndria?",
      kind: "discursive",
      points: 2,
      bncc_skill: "EF06CI05"
    )
    question.image.attach(
      io: StringIO.new("\x89PNG\r\n\x1A\n"),
      filename: "mito.png",
      content_type: "image/png"
    )
  end

  test "packs lesson without database ids" do
    payload = Lessons::Packager.new(lessons: [ @lesson.reload ]).as_json

    assert_equal "maestro.lesson.pack", payload["format"]
    assert_equal 1, payload["version"]
    packed = payload["lessons"].first
    assert_nil packed["id"]
    assert_equal @professor.id, packed["professor_id"]
    assert_equal "pending", packed["siage_shipment"]["status"]
    assert_equal "Célula", packed["theme"]
    assert_equal "2ª F", packed["classroom"]["name"]
    assert_equal "2º ano", packed["classroom"]["grade_level"]
    assert_equal "Ciências", packed["course"]["name"]
    assert_equal "Lista", packed["activity"]["title"]
    assert_equal "O que é mitocôndria?", packed["activity"]["questions"].first["prompt"]
    assert packed["activity"]["questions"].first["image"]["data"].present?
    refute packed.key?("id")
    assert_equal [], packed["attendance"]
  end

  test "packs attendance and grades by student name" do
    student = @professor.students.create!(name: "Maria Silva")
    enrollment = Enrollment.create!(
      professor: @professor,
      student: student,
      classroom: @classroom,
      enrolled_on: Date.new(2026, 2, 1),
      status: "active"
    )
    AttendanceRecord.create!(
      professor: @professor,
      enrollment: enrollment,
      lesson: @lesson,
      attendance_date: @lesson.lesson_date,
      status: "absent"
    )
    @activity.activity_submissions.create!(
      professor: @professor,
      student: student,
      score: 7.5,
      submitted_on: Date.new(2026, 10, 13)
    )

    packed = Lessons::Packager.new(lessons: [ @lesson.reload ]).as_json["lessons"].first

    assert_equal "Maria Silva", packed["attendance"].first["student_name"]
    assert_equal "absent", packed["attendance"].first["status"]
    assert_equal "Maria Silva", packed["activity"]["submissions"].first["student_name"]
    assert_equal 7.5, packed["activity"]["submissions"].first["score"].to_f
    refute packed["attendance"].first.key?("student_id")
  end

  test "packs current SIAGE ledger status" do
    SiageShipment.record!(
      professor: @professor,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      status: "already_registered"
    )

    packed = Lessons::Packager.new(lessons: [ @lesson.reload ]).as_json["lessons"].first

    assert_equal "already_registered", packed["siage_shipment"]["status"]
    assert_equal "lesson", packed["siage_shipment"]["kind"]
  end
end
