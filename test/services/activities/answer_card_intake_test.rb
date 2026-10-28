require "test_helper"

class Activities::AnswerCardIntakeTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "card-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "3º ano")
    @classroom = @professor.classrooms.create!(
      name: "3ª M",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.current,
      theme: "Função",
      has_activity: true,
      siage_time_slot: "1º tempo"
    )
    @activity = lesson.create_activity!(
      title: "Prova de funções",
      activity_type: "Prova",
      due_date: Date.current,
      bimester: 4,
      weight: 1,
      maximum_score: 10
    )
    question = @professor.questions.create!(
      prompt: "2 + 2?",
      kind: "objective",
      choices: [
        { "letter" => "A", "text" => "4" },
        { "letter" => "B", "text" => "3" }
      ],
      correct_letter: "A",
      points: 1
    )
    @item = Activities::Composer.new(@activity).add(question)
    @maria = @professor.students.create!(name: "MARIA SILVA")
    @joao = @professor.students.create!(name: "JOÃO NUNES")
    Enrollment.create!(professor: @professor, student: @maria, classroom: @classroom, enrolled_on: Date.current, status: "active")
    Enrollment.create!(professor: @professor, student: @joao, classroom: @classroom, enrolled_on: Date.current, status: "active")
  end

  test "maps bubble 1 to the first question and launches a unique name" do
    intake = Activities::AnswerCardIntake.new(
      @activity,
      professor: @professor,
      vision: ->(_path) {
        Activities::AnswerCardVision::Result.new(
          name: "Maria Silva",
          answers: { "1" => "A" },
          source: "lira"
        )
      }
    )

    result = intake.ingest!([upload("maria.png")])

    assert_equal 1, result.launched
    submission = ActivitySubmission.find_by!(activity: @activity, student: @maria)
    assert_equal 10.0, submission.score
    assert_equal "A", submission.answers[@item.id.to_s]
  end

  test "keeps an uncertain card as pending" do
    intake = Activities::AnswerCardIntake.new(
      @activity,
      professor: @professor,
      vision: ->(_path) {
        Activities::AnswerCardVision::Result.new(
          name: nil,
          answers: { "1" => "B" },
          source: "lira"
        )
      }
    )

    result = intake.ingest!([upload("scan.png")])

    assert_equal 1, result.pending
    assert_equal 0, ActivitySubmission.count
    card = @activity.pending_cards.last
    assert_equal "B", card.answers["1"]
  end

  test "phone photo of a known student launches the grade" do
    intake = Activities::AnswerCardIntake.new(
      @activity,
      professor: @professor,
      vision: ->(_path) {
        Activities::AnswerCardVision::Result.new(
          name: nil,
          answers: { "1" => "A" },
          source: "lira"
        )
      }
    )

    result = intake.scan_for_student!(upload("alerrandro.jpg"), student: @maria, overwrite: true)

    assert_equal :launched, result.status
    assert_equal 10.0, result.score
    submission = ActivitySubmission.find_by!(activity: @activity, student: @maria)
    assert_equal "A", submission.answers[@item.id.to_s]
  end

  test "phone photo overwrites a previous score for that student" do
    ActivitySubmission.create!(
      activity: @activity,
      student: @maria,
      professor: @professor,
      score: 3.0,
      submitted_on: Date.current,
      answers: { @item.id.to_s => "B" }
    )
    intake = Activities::AnswerCardIntake.new(
      @activity,
      professor: @professor,
      vision: ->(_path) {
        Activities::AnswerCardVision::Result.new(
          name: nil,
          answers: { "1" => "A" },
          source: "lira"
        )
      }
    )

    result = intake.scan_for_student!(upload("maria.jpg"), student: @maria, overwrite: true)

    assert_equal :launched, result.status
    assert_equal 10.0, ActivitySubmission.find_by!(activity: @activity, student: @maria).score
  end

  test "does not overwrite a recorded score" do
    ActivitySubmission.create!(
      activity: @activity,
      student: @maria,
      professor: @professor,
      score: 8.0,
      submitted_on: Date.current,
      answers: { @item.id.to_s => "B" }
    )
    intake = Activities::AnswerCardIntake.new(
      @activity,
      professor: @professor,
      vision: ->(_path) {
        Activities::AnswerCardVision::Result.new(
          name: "Maria Silva",
          answers: { "1" => "A" },
          source: "lira"
        )
      }
    )

    result = intake.ingest!([upload("maria.png")])

    assert_equal 1, result.skipped
    assert_equal 8.0, ActivitySubmission.find_by!(activity: @activity, student: @maria).score
  end

  private

  def upload(name)
    file = Tempfile.new(["card", File.extname(name).presence || ".png"])
    file.binmode
    file.write("fake")
    file.flush
    file.rewind
    @uploads ||= []
    @uploads << file
    Rack::Test::UploadedFile.new(file.path, "image/png")
  end
end
