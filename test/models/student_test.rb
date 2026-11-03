require "test_helper"

class StudentTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "destroy_with_history clears submissions and attendance" do
    professor = Professor.create!(
      name: "Ana Souza",
      email: "student-model-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = professor.grade_levels.create!(name: "3º ano")
    classroom = professor.classrooms.create!(
      name: "3ª N",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    student = professor.students.create!(name: "RAISSA DA COSTA")
    enrollment = Enrollment.create!(
      professor: professor,
      student: student,
      classroom: classroom,
      enrolled_on: Date.current,
      status: "active"
    )
    AttendanceRecord.create!(
      professor: professor,
      enrollment: enrollment,
      attendance_date: Date.current,
      status: "present"
    )

    student.destroy_with_history!

    assert_nil Student.find_by(id: student.id)
    assert_equal 0, Enrollment.where(id: enrollment.id).count
    assert_equal 0, AttendanceRecord.where(enrollment_id: enrollment.id).count
  end

  test "destroy_with_history clears exam assignments and ENEM sheets" do
    professor = Professor.create!(
      name: "Ana Souza",
      email: "student-exam-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = professor.grade_levels.create!(name: "3º ano")
    classroom = professor.classrooms.create!(
      name: "3ª N",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    student = professor.students.create!(name: "ALERRANDRO VITOR")
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
      theme: "Prova",
      content: "Avaliação",
      has_activity: true
    )
    activity = lesson.create_activity!(
      title: "Prova",
      activity_type: "Prova",
      due_date: Date.current,
      bimester: 1,
      weight: 1,
      maximum_score: 10
    )
    ActivityExamAssignment.create!(activity: activity, student: student, slot: 1)
    simulado = professor.enem_simulados.create!(
      classroom: classroom,
      title: "Simulado",
      applied_on: Date.current,
      bimester: 1,
      question_count: 90
    )
    EnemSimuladoSheet.create!(enem_simulado: simulado, student: student, classroom: classroom)

    student.destroy_with_history!

    assert_nil Student.find_by(id: student.id)
    assert_equal 0, ActivityExamAssignment.where(student_id: student.id).count
    assert_equal 0, EnemSimuladoSheet.where(student_id: student.id).count
  end
end
