require "test_helper"

class PublicCorrectionsControllerTest < ActionDispatch::IntegrationTest
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "gabarito-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "2º ano")
    classroom = @professor.classrooms.create!(
      name: "2ª S",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    lesson = @professor.lessons.create!(
      classroom: classroom,
      lesson_date: Date.current,
      theme: "Célula",
      siage_time_slot: "1",
      has_activity: true
    )
    @activity = lesson.create_activity!(
      title: "Lista genética",
      activity_type: "Prova",
      due_date: Date.current,
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
    @item = Activities::Composer.new(@activity).add(
      @professor.questions.create!(
        prompt: "Mitocôndria produz?",
        kind: "objective",
        choices: [
          { "letter" => "A", "text" => "ATP" },
          { "letter" => "B", "text" => "DNA" }
        ],
        correct_letter: "A",
        points: 1
      )
    )
    @student = @professor.students.create!(name: "João")
    Enrollment.create!(
      professor: @professor,
      student: @student,
      classroom: classroom,
      enrolled_on: Date.current,
      status: "active"
    )
  end

  test "phone camera can open gabarito without login" do
    get gabarito_path(@activity.correction_token)

    assert_response :success
    assert_match "João", response.body
  end

  test "student qr opens that pupil and posts the grade" do
    get gabarito_aluno_path(@activity.correction_token, @student)
    assert_response :success
    assert_match "Mitocôndria", response.body

    post gabarito_grade_path(@activity.correction_token), params: {
      student_id: @student.id,
      answers: { @item.id.to_s => "A" }
    }

    assert_redirected_to gabarito_aluno_path(@activity.correction_token, @student, ok: 1)
    follow_redirect!
    assert_match "10,0", response.body
    submission = ActivitySubmission.find_by(activity: @activity, student: @student)
    assert_equal 10.0, submission.score
  end

  test "unknown token is not found" do
    get gabarito_path("token-inexistente")
    assert_response :not_found
  end
end
