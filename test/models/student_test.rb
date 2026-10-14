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
end
