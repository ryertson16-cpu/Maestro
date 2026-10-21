require "test_helper"

class Documents::ClassroomRosterTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "renders a pdf with classroom student names" do
    professor = Professor.create!(
      name: "Ana Souza",
      email: "roster-#{SecureRandom.hex(4)}@maestro.test",
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
    first = professor.students.create!(name: "Breno Silva")
    second = professor.students.create!(name: "Ana Lima")
    [first, second].each do |student|
      Enrollment.create!(
        professor: professor,
        student: student,
        classroom: classroom,
        enrolled_on: Date.current,
        status: "active"
      )
    end

    pdf = Documents::ClassroomRoster.new(
      professor: professor,
      classroom: classroom,
      enrollments: classroom.enrollments.includes(:student).joins(:student).order("students.name")
    ).render

    assert pdf.start_with?("%PDF")
    assert pdf.bytesize > 200
  end
end
