require "test_helper"

class EnemSimuladosControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "enem-#{SecureRandom.hex(4)}@maestro.test",
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
    @other_classroom = @professor.classrooms.create!(
      name: "3ª N",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @student = @professor.students.create!(name: "Maria Silva")
    @other = @professor.students.create!(name: "João Vitor Oliveira")
    Enrollment.create!(
      professor: @professor,
      student: @student,
      classroom: @classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    Enrollment.create!(
      professor: @professor,
      student: @other,
      classroom: @other_classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    sign_in @professor
  end

  test "parses official key, reads a named card and launches 0-10 score from total hits" do
    key = (1..90).map { |index| %w[A B C D E][(index - 1) % 5] }
    answers = key.map.with_index { |letter, index|
      index < 45 ? (letter == "A" ? "B" : "A") : letter
    }

    post enem_simulados_path, params: {
      classroom_id: @classroom.id,
      title: "Simulado ENEM — CN e Matemática",
      applied_on: "2026-10-16",
      bimester: 4,
      official_pdf: uploaded_gabarito(key)
    }

    simulado = EnemSimulado.find_by!(title: "Simulado ENEM — CN e Matemática")
    assert_redirected_to enem_simulado_path(simulado)

    patch update_key_enem_simulado_path(simulado), params: key_params(simulado.normalized_key)
    simulado.reload
    assert simulado.key_confirmed?

    post create_sheet_enem_simulado_path(simulado), params: {
      student_id: @student.id,
      card_pdfs: [uploaded_gabarito(answers, filename: "Maria Silva.pdf")]
    }
    assert_redirected_to enem_simulado_path(simulado)

    sheet = simulado.sheets.find_by!(student: @student)
    refute sheet.confirmed?
    assert_equal @classroom.id, sheet.classroom_id
    assert_equal 0, sheet.cn_hits
    assert_equal 45, sheet.mt_hits
    assert_equal 45, sheet.hits
    assert_equal 6.0, sheet.score

    patch enem_simulado_sheet_path(simulado, sheet), params: {
      commit: "Lançar nota no caderno",
      answers: letter_hash(sheet.normalized_answers)
    }

    sheet.reload
    assert sheet.confirmed?
    submission = simulado.activity.activity_submissions.find_by!(student: @student)
    assert_equal 6.0, submission.score
  end

  test "matches several PDFs by student name, fills classroom, bulk-imports and can remove a card" do
    key = Array.new(90, "A")
    simulado = create_confirmed_simulado(key)

    post create_sheet_enem_simulado_path(simulado), params: {
      card_pdfs: [
        uploaded_gabarito(key, filename: "Maria Silva.pdf"),
        uploaded_gabarito(Array.new(90, "B"), filename: "Joao Vitor Oliveira.pdf")
      ]
    }

    maria = simulado.sheets.find_by!(student: @student)
    joao = simulado.sheets.find_by!(student: @other)
    assert_equal "3ª M", maria.classroom_label
    assert_equal "3ª N", joao.classroom_label
    assert_equal 90, maria.hits
    assert_equal 0, joao.hits
    assert_equal 45, maria.cn_hits
    assert_equal 45, maria.mt_hits

    post import_sheets_enem_simulado_path(simulado)
    assert_equal 10.0, maria.reload.score
    assert maria.confirmed?
    assert_equal 10.0, simulado.activity.activity_submissions.find_by!(student: @student).score

    other_activity = Activity.joins(:lesson).find_by!(
      title: simulado.title,
      lessons: { classroom_id: @other_classroom.id }
    )
    assert_equal 0.0, other_activity.activity_submissions.find_by!(student: @other).score

    delete enem_simulado_sheet_path(simulado, maria)
    refute simulado.sheets.exists?(id: maria.id)
    assert simulado.activity.activity_submissions.exists?(student: @student)
  end

  test "matches the handwritten name when Lira reads the scanned card" do
    key = Array.new(90, "A")
    simulado = create_confirmed_simulado(key)
    scan = Enem::CardReader::Scan.new(
      name: "Maria Silva",
      letters: key,
      source: "lira"
    )
    singleton = Enem::CardReader.singleton_class
    original = singleton.instance_method(:read)
    singleton.define_method(:read) { |*| scan }

    post create_sheet_enem_simulado_path(simulado), params: {
      card_pdfs: [uploaded_gabarito(key, filename: "Misturado-4.pdf")]
    }
    perform_enqueued_jobs

    sheet = simulado.sheets.find_by!(student: @student)
    assert_equal "lira", sheet.suggestion_source
    assert_equal 90, sheet.hits
    assert_equal 0, simulado.pending_cards.count
  ensure
    # restore CardReader.read after the handwritten-name stub
    singleton&.define_method(:read, original) if original
  end

  test "downloads a results report pdf" do
    key = Array.new(90, "A")
    simulado = create_confirmed_simulado(key)
    post create_sheet_enem_simulado_path(simulado), params: {
      card_pdfs: [uploaded_gabarito(key, filename: "Maria Silva.pdf")]
    }

    get report_enem_simulado_path(simulado)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/relatorio-simulado-enem/, response.headers["Content-Disposition"].to_s)
    assert response.body.start_with?("%PDF")
  end

  test "stores every scanner PDF even when the first filename has no student" do
    key = Array.new(90, "A")
    simulado = create_confirmed_simulado(key)

    post create_sheet_enem_simulado_path(simulado), params: {
      card_pdfs: [
        uploaded_gabarito(key, filename: "Misturado-5.pdf"),
        uploaded_gabarito(key, filename: "Misturado-6.pdf"),
        uploaded_gabarito(key, filename: "Misturado-7.pdf")
      ]
    }

    assert_redirected_to enem_simulado_path(simulado)
    assert_equal 3, simulado.pending_cards.count
    assert_equal %w[Misturado-5.pdf Misturado-6.pdf Misturado-7.pdf].sort,
                 simulado.pending_cards.pluck(:filename).sort
  end

  test "keeps a scanner-named PDF so the professor can pick the student afterwards" do
    key = Array.new(90, "A")
    simulado = create_confirmed_simulado(key)

    post create_sheet_enem_simulado_path(simulado), params: {
      card_pdfs: [uploaded_gabarito(key, filename: "Misturado-3.pdf")]
    }

    assert_redirected_to enem_simulado_path(simulado)
    assert_equal 0, simulado.sheets.count
    pending = simulado.pending_cards.find_by!(filename: "Misturado-3.pdf")
    assert pending.card_pdf.attached?

    perform_enqueued_jobs
    pending = simulado.pending_cards.find_by!(filename: "Misturado-3.pdf")

    post assign_enem_simulado_pending_card_path(simulado, pending), params: { student_id: @student.id }
    assert_equal 1, simulado.sheets.where(student: @student).count
    refute simulado.pending_cards.exists?(id: pending.id)
  end

  private

  def create_confirmed_simulado(key)
    post enem_simulados_path, params: {
      classroom_id: @classroom.id,
      title: "Simulado ENEM — CN e Matemática",
      applied_on: "2026-10-16",
      bimester: 4,
      official_pdf: uploaded_gabarito(key)
    }
    simulado = EnemSimulado.find_by!(title: "Simulado ENEM — CN e Matemática")
    patch update_key_enem_simulado_path(simulado), params: key_params(simulado.normalized_key)
    simulado.reload
  end

  def uploaded_gabarito(letters, filename: nil)
    path = Rails.root.join("tmp", filename.presence || "enem-#{SecureRandom.hex(8)}.pdf")
    Prawn::Document.generate(path) do |pdf|
      letters.each_with_index do |letter, index|
        pdf.text "#{index + 1} #{letter}"
      end
    end
    Rack::Test::UploadedFile.new(path, "application/pdf")
  end

  def key_params(letters)
    { key: letter_hash(letters) }
  end

  def letter_hash(letters)
    letters.each_with_index.to_h { |letter, index| [(index + 1).to_s, letter] }
  end
end
