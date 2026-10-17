require "test_helper"

class Documents::DayDiaryTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "renders a pdf with theme and attendance" do
    professor = Professor.create!(
      name: "Ana Souza",
      email: "diary-pdf-#{SecureRandom.hex(4)}@maestro.test",
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
    student = professor.students.create!(name: "Maria")
    enrollment = Enrollment.create!(
      professor: professor,
      student: student,
      classroom: classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    lesson = professor.lessons.create!(
      classroom: classroom,
      lesson_date: Date.new(2026, 10, 16),
      theme: "Fotossíntese",
      content: "Cloroplastos",
      siage_time_slot: "1º tempo"
    )
    record = AttendanceRecord.create!(
      professor: professor,
      enrollment: enrollment,
      lesson: lesson,
      attendance_date: lesson.lesson_date,
      status: "late"
    )

    pdf = Documents::DayDiary.new(
      professor: professor,
      classroom: classroom,
      date: lesson.lesson_date,
      lessons: [lesson],
      enrollments: [enrollment],
      records_by_lesson: { lesson.id => { enrollment.id => record } }
    ).render

    assert pdf.start_with?("%PDF")
    assert pdf.bytesize > 200
  end
end
