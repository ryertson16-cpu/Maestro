require "test_helper"

class Activities::PackagerTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "act-pack-#{SecureRandom.hex(4)}@maestro.test",
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
      has_activity: true
    )
    @activity = @lesson.create_activity!(
      title: "Lista",
      activity_type: "Lista de exercícios",
      due_date: Date.new(2026, 10, 14),
      bimester: 1,
      weight: 1,
      maximum_score: 10,
      description: "Organelas",
      instructions: "Responda"
    )
    @activity.activity_questions.create!(
      position: 1,
      prompt: "O que é mitocôndria?",
      kind: "discursive",
      points: 2,
      bncc_skill: "EF06CI05"
    )
  end

  test "packs activity without database ids" do
    payload = Activities::Packager.new(activities: [ @activity.reload ]).as_json

    assert_equal "maestro.activity.pack", payload["format"]
    packed = payload["activities"].first
    assert_nil packed["id"]
    refute packed.key?("professor_id")
    refute packed.key?("attendance")
    assert_equal "Célula", packed["theme"]
    assert_equal "2ª F", packed["classroom"]["name"]
    assert_equal "Lista", packed["activity"]["title"]
    assert_equal "Organelas", packed["activity"]["description"]
    assert_equal "O que é mitocôndria?", packed["activity"]["questions"].first["prompt"]
  end

  test "packs grades by student name" do
    student = @professor.students.create!(name: "Maria Silva")
    Enrollment.create!(
      professor: @professor,
      student: student,
      classroom: @classroom,
      enrolled_on: Date.new(2026, 2, 1),
      status: "active"
    )
    @activity.activity_submissions.create!(
      professor: @professor,
      student: student,
      score: 8.0,
      submitted_on: Date.new(2026, 10, 13)
    )

    packed = Activities::Packager.new(activities: [ @activity.reload ]).as_json["activities"].first

    assert_equal "Maria Silva", packed["activity"]["submissions"].first["student_name"]
    assert_equal 8.0, packed["activity"]["submissions"].first["score"].to_f
  end
end
