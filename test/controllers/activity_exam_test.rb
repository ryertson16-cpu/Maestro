require "test_helper"

class ActivityExamTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "exam-ctl-#{SecureRandom.hex(4)}@maestro.test",
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
    @question = @professor.questions.create!(
      prompt: "2 + 2?",
      kind: "objective",
      choices: [
        { "letter" => "A", "text" => "4" },
        { "letter" => "B", "text" => "3" }
      ],
      correct_letter: "A",
      points: 1
    )
    @student = @professor.students.create!(name: "MARIA SILVA")
    Enrollment.create!(professor: @professor, student: @student, classroom: @classroom, enrolled_on: Date.current, status: "active")
    sign_in @professor
  end

  test "build exam includes bank questions" do
    post build_exam_activity_path(@activity), params: {
      topic: "2 + 2",
      quantity: 1,
      mix: "objective"
    }

    assert_redirected_to assemble_activity_path(@activity)
    assert_equal 1, @activity.activity_questions.count
  end

  test "student sheet and answer key are pdfs" do
    Activities::Composer.new(@activity).add(@question)

    get sheet_activity_path(@activity, format: :pdf)
    assert_response :success
    assert_match "application/pdf", response.media_type

    get key_sheet_activity_path(@activity, format: :pdf)
    assert_response :success
    assert_match "application/pdf", response.media_type
  end

  test "scan without lira does not change an existing grade" do
    item = Activities::Composer.new(@activity).add(@question)
    ActivitySubmission.create!(
      activity: @activity,
      student: @student,
      professor: @professor,
      score: 7.0,
      submitted_on: Date.current,
      answers: { item.id.to_s => "B" }
    )

    file = Tempfile.new(["card", ".png"])
    file.binmode
    file.write("x")
    file.close

    post scan_cards_activity_path(@activity), params: {
      cards: [Rack::Test::UploadedFile.new(file.path, "image/png")]
    }

    assert_redirected_to assemble_activity_path(@activity)
    assert_equal 7.0, ActivitySubmission.find_by!(activity: @activity, student: @student).score
  ensure
    file&.unlink
  end
end
