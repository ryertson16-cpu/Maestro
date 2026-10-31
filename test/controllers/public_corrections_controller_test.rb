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
    get gabarito_path(@activity.correction_token),
        headers: { "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1" }

    assert_response :success
    assert_match "João", response.body
    assert_match "Ler QR da folha do aluno", response.body
    assert_includes response.body, 'capture="environment"'
    refute_match(/variante/i, response.body)
    refute_match "Aguardando a câmera deste celular", response.body
    assert_match(/câmera do celular não liga/i, response.body)
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
    assert_match "Gabarito corrigido", response.body
    assert_match "10,0", response.body
    submission = ActivitySubmission.find_by(activity: @activity, student: @student)
    assert_equal 10.0, submission.score
  end

  test "phone photo of the student card launches the grade" do
    file = Tempfile.new(["card", ".jpg"])
    file.binmode
    file.write("fake-photo")
    file.close

    fake = Activities::AnswerCardVision::Result.new(
      name: nil,
      answers: { "1" => "A" },
      source: "lira"
    )
    lira = Lira.method(:llm_enabled?)
    scan = Activities::AnswerCardVision.method(:scan)
    Lira.define_singleton_method(:llm_enabled?) { true }
    Activities::AnswerCardVision.define_singleton_method(:scan) { |*| fake }

    post gabarito_scan_path(@activity.correction_token), params: {
      student_id: @student.id,
      card: Rack::Test::UploadedFile.new(file.path, "image/jpeg")
    }

    assert_redirected_to gabarito_aluno_path(@activity.correction_token, @student, ok: 1)
    submission = ActivitySubmission.find_by!(activity: @activity, student: @student)
    assert_equal 10.0, submission.score
    assert submission.card_photo.attached?
  ensure
    Lira.define_singleton_method(:llm_enabled?, lira) if lira
    Activities::AnswerCardVision.define_singleton_method(:scan, scan) if scan
    file&.unlink
  end

  test "unknown token is not found" do
    get gabarito_path("token-inexistente")
    assert_response :not_found
  end

  test "six-digit pin opens the gabarito without scanning a url" do
    pin = @activity.ensure_correction_pin!

    get correction_gate_path
    assert_response :success
    assert_match(/Digite o código da prova/, response.body)

    post correction_gate_path, params: { pin: pin }
    assert_redirected_to gabarito_path(@activity.correction_token)

    get correction_pin_path(pin)
    assert_redirected_to gabarito_path(@activity.correction_token)
  end
end
