require "test_helper"

class Documents::EnemSimuladoReportTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "renders a pdf with student hits and suggested score" do
    professor = Professor.create!(
      name: "Ana Souza",
      email: "enem-report-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = professor.grade_levels.create!(name: "3º ano")
    classroom = professor.classrooms.create!(
      name: "3ª M",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    student = professor.students.create!(name: "Maria Silva")
    Enrollment.create!(
      professor: professor,
      student: student,
      classroom: classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    simulado = professor.enem_simulados.create!(
      classroom: classroom,
      title: "Simulado ENEM — CN e Matemática",
      applied_on: Date.new(2026, 10, 20),
      bimester: 4,
      question_count: 90,
      official_key: Array.new(90, "A"),
      key_confirmed: true
    )
    sheet = simulado.sheets.create!(
      student: student,
      classroom: classroom,
      answers: Array.new(90, "A"),
      suggestion_source: "pdf",
      confirmed: false
    )
    sheet.recompute!
    sheet.save!

    pdf = Documents::EnemSimuladoReport.new(
      professor: professor,
      simulado: simulado,
      sheets: [sheet]
    ).render

    assert pdf.start_with?("%PDF")
    assert pdf.bytesize > 200
  end
end
