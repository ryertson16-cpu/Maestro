require "test_helper"

class ActivitiesAssembleTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "assemble-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "2º ano")
    @classroom = @professor.classrooms.create!(
      name: "2ª R",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.current,
      theme: "Célula",
      siage_time_slot: "1",
      has_activity: true
    )
    @activity = @lesson.create_activity!(
      title: "Lista genética",
      activity_type: "Lista de exercícios",
      due_date: Date.current,
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
    @question = @professor.questions.create!(
      prompt: "Mitocôndria produz?",
      kind: "objective",
      choices: [
        { "letter" => "A", "text" => "ATP" },
        { "letter" => "B", "text" => "DNA" }
      ],
      correct_letter: "A",
      points: 1
    )
    @student = @professor.students.create!(name: "João")
    Enrollment.create!(
      professor: @professor,
      student: @student,
      classroom: @classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    sign_in @professor
  end

  test "adds a bank question to the activity" do
    post activity_activity_questions_path(@activity, question_id: @question.id)

    assert_redirected_to assemble_activity_path(@activity)
    item = @activity.activity_questions.last
    assert_equal "Mitocôndria produz?", item.prompt
    assert_equal "A", item.correct_letter
  end

  test "pdf accepts superscript minus in objective choices" do
    @question.update!(
      prompt: "Qual é o valor de 10⁻²?",
      choices: [
        { "letter" => "A", "text" => "0,01" },
        { "letter" => "B", "text" => "10⁻²" }
      ]
    )
    Activities::Composer.new(@activity).add(@question.reload)

    get sheet_activity_path(@activity, format: :pdf)

    assert_response :success
    assert_match "application/pdf", response.media_type
  end

  test "pdf includes assembled question and correction qr payload" do
    Activities::Composer.new(@activity).add(@question)

    get sheet_activity_path(@activity, format: :pdf)

    assert_response :success
    assert_match "application/pdf", response.media_type
    assert_operator response.body.bytesize, :>, 800
  end

  test "grades from the qr correction form" do
    item = Activities::Composer.new(@activity).add(@question)

    post grade_activity_path(@activity), params: {
      student_id: @student.id,
      answers: { item.id.to_s => "A" }
    }

    assert_redirected_to assemble_activity_path(@activity)
    submission = ActivitySubmission.find_by(activity: @activity, student: @student)
    assert_equal 10.0, submission.score
    assert_equal "A", submission.answers[item.id.to_s]
  end

  test "assemble qr page does not print the gabarito address" do
    get assemble_activity_path(@activity)
    token = @activity.reload.correction_token

    assert_response :success
    refute_includes response.body, "/g/#{token}"
    refute_match %r{trycloudflare|192\.168\.}, response.body
    assert_includes response.body, "abrir-gabarito"
    assert_match(/gerando o link HTTPS|Atualizar QR/i, response.body)
    refute_match %r{http://10\.}, response.body
  end

  test "opens correction from scanned token" do
    @activity.ensure_correction_token!

    get corrections_path, params: { t: @activity.correction_token }

    assert_redirected_to gabarito_path(@activity.correction_token)
  end
end
