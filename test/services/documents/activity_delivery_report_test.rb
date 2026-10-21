require "test_helper"

class Documents::ActivityDeliveryReportTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "renders a pdf with student name, status and receipt date" do
    professor = Professor.create!(
      name: "Ana Souza",
      email: "activity-report-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = professor.grade_levels.create!(name: "2º ano")
    classroom = professor.classrooms.create!(
      name: "2ª F",
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
    lesson = professor.lessons.create!(
      classroom: classroom,
      lesson_date: Date.current,
      theme: "Celula",
      siage_time_slot: "1º tempo",
      has_activity: true
    )
    activity = lesson.create_activity!(
      title: "Lista genetica",
      activity_type: "Lista de exercícios",
      due_date: Date.current,
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
    ActivitySubmission.create!(
      activity: activity,
      student: student,
      professor: professor,
      score: 8,
      submitted_on: Date.current
    )

    pdf = Documents::ActivityDeliveryReport.new(
      professor: professor,
      classroom: classroom,
      activity: activity
    ).render

    assert pdf.start_with?("%PDF")
    assert pdf.bytesize > 200
  end
end
