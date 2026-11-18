require "test_helper"

class IndividualActivities::BuilderTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "individual-#{SecureRandom.hex(4)}@maestro.test",
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
    @ana = @professor.students.create!(name: "Ana")
    @bia = @professor.students.create!(name: "Bia")
    [ @ana, @bia ].each do |student|
      Enrollment.create!(
        professor: @professor,
        student: student,
        classroom: @classroom,
        enrolled_on: Date.current,
        status: "active"
      )
    end
    @question = @professor.questions.create!(
      prompt: "Quanto é 2 + 2?",
      kind: "objective",
      choices: [
        { "letter" => "A", "text" => "3" },
        { "letter" => "B", "text" => "4" }
      ],
      correct_letter: "B",
      points: 2
    )
  end

  test "builds an activity for the chosen student only" do
    activity = IndividualActivities::Builder.new(
      professor: @professor,
      classroom: @classroom,
      student: @ana,
      questions: [ @question ]
    ).create!

    assert activity.adapted?
    assert activity.assigned_to?(@ana)
    refute activity.assigned_to?(@bia)
    assert_equal [ @question.prompt ], activity.activity_questions.map(&:prompt)
    assert activity.lesson.individual?
    assert_equal 2, activity.maximum_score
    refute_includes Siage::Ledger.new(professor: @professor, classroom: @classroom).open_lessons, activity.lesson
  end
end
