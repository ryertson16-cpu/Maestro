require "test_helper"

class Activities::ExamResultTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana",
      email: "exam-result-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "3º ano")
    @classroom = @professor.classrooms.create!(name: "3ª A", school_year: 2026, grade_level: grade, active: true)
    lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.current,
      theme: "Função",
      has_activity: true,
      siage_time_slot: "1"
    )
    @activity = lesson.create_activity!(
      title: "Prova 3",
      activity_type: "Prova",
      due_date: Date.current,
      bimester: 4,
      weight: 1,
      maximum_score: 10
    )
    @item = @activity.activity_questions.create!(
      position: 1,
      prompt: "2+2?",
      kind: "objective",
      choices: [
        { "letter" => "A", "text" => "4" },
        { "letter" => "B", "text" => "3" }
      ],
      correct_letter: "A",
      points: 10
    )
    @ana = @professor.students.create!(name: "Ana Beatriz Rocha")
    @bruno = @professor.students.create!(name: "Bruno")
    [ @ana, @bruno ].each do |student|
      Enrollment.create!(professor: @professor, student: student, classroom: @classroom, enrolled_on: Date.current, status: "active")
    end
  end

  test "groups the same bank question even when printed order differs" do
    ActivitySubmission.create!(
      activity: @activity,
      student: @ana,
      professor: @professor,
      score: 10,
      submitted_on: Date.current,
      answers: { @item.id.to_s => "A" }
    )
    ActivitySubmission.create!(
      activity: @activity,
      student: @bruno,
      professor: @professor,
      score: 0,
      submitted_on: Date.current,
      answers: { @item.id.to_s => "B" }
    )

    result = Activities::ExamResult.new(@activity)
    stat = result.item_stats.first

    assert_equal "Q1", stat.label
    assert_equal 50, stat.rate
    assert_equal 5.0, result.average
    assert_equal 1, result.pass_count
    assert_equal @item.id, result.hardest.item.id
  end
end
