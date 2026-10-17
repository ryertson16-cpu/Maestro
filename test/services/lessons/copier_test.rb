require "test_helper"

class Lessons::CopierTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "copier-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "2º ano")
    @classroom = @professor.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @other = @professor.classrooms.create!(
      name: "2ª G",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.new(2026, 10, 12),
      theme: "Célula",
      content: "Organelas",
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
    @activity.activity_questions.create!(
      position: 1,
      prompt: "O que é mitocôndria?",
      kind: "discursive",
      points: 2,
      bncc_skill: "EF06CI05"
    )
  end

  test "copies lesson theme and activity questions to another day" do
    replica = Lessons::Copier.new(
      professor: @professor,
      lesson: @lesson,
      classroom: @classroom,
      lesson_date: Date.new(2026, 10, 19),
      copy_activities: true
    ).call

    assert_equal "Célula", replica.theme
    assert_equal "EF06CI05", replica.skills
    copied = replica.reload.activity
    assert_equal "Lista", copied.title
    assert_equal Date.new(2026, 10, 21), copied.due_date
    assert_equal "EF06CI05", copied.activity_questions.first.bncc_skill
    assert_equal 0, copied.activity_submissions.count
  end

  test "skips adapted versions when classroom changes" do
    student = @professor.students.create!(name: "João")
    Enrollment.create!(
      professor: @professor,
      student: student,
      classroom: @classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    adapted = @activity.adapted_versions.build(
      lesson: @lesson,
      title: "Lista reduzida",
      activity_type: "Lista de exercícios",
      due_date: @activity.due_date,
      bimester: 1,
      weight: 1,
      adapted: true,
      adaptation_kind: "reduced",
      grade_mode: "replaces"
    )
    adapted.activity_recipients.build(student: student)
    adapted.save!

    replica = Lessons::Copier.new(
      professor: @professor,
      lesson: @lesson.reload,
      classroom: @other,
      lesson_date: Date.new(2026, 10, 19),
      copy_activities: true
    ).call

    assert replica.activities.regular.exists?
    assert_equal 0, replica.activities.adapted.count
  end
end
