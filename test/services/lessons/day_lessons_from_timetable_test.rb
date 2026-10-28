require "test_helper"

class Lessons::DayLessonsFromTimetableTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      preferred_name: "Ryertson",
      email: "dia-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    @course = @professor.courses.create!(
      name: "Química",
      knowledge_area: "ciencias_da_natureza",
      active: true
    )
    grade = @professor.grade_levels.create!(name: "2º ano")
    %w[2ª\ F 2ª\ H 2ª\ I 3ª\ K 3ª\ L 3ª\ M 3ª\ N 3ª\ O].each do |name|
      @professor.classrooms.create!(
        name: name,
        school_year: 2026,
        grade_level: grade,
        active: true
      )
    end
  end

  test "creates every ryertson chemistry lesson for a past thursday" do
    path = Rails.root.join("test/fixtures/files/novo_horario.pdf")
    skip "PDF do horário não está nos fixtures" unless path.exist?

    upload = Rack::Test::UploadedFile.new(path, "application/pdf")
    date = Date.new(2026, 10, 22)

    result = Lessons::DayLessonsFromTimetable.new(
      professor: @professor,
      lesson_date: date,
      upload: upload
    ).call

    assert result[:ok], result[:error]
    assert_operator result[:created], :>=, 2

    lessons = @professor.lessons.where(lesson_date: date).includes(:classroom, :course)
    assert_operator lessons.size, :>=, 5
    assert lessons.all? { |lesson| lesson.course.name == "Química" }
    assert_not lessons.joins(:course).exists?(courses: { name: "Física" })
    %w[F H L M N K].each do |letter|
      assert lessons.joins(:classroom).exists?(["classrooms.name LIKE ?", "%#{letter}%"]),
             "esperava aula na turma #{letter} na quinta"
    end
  end

  test "does not invent physics when the professor only teaches chemistry" do
    classroom = @professor.classrooms.find_by(name: "2ª F")
    @professor.timetable_entries.create!(
      classroom: classroom,
      course: @course,
      weekday: 4,
      period: 2,
      time_slot: "2º tempo"
    )

    result = Lessons::DayLessonsFromTimetable.new(
      professor: @professor,
      lesson_date: Date.new(2026, 10, 22)
    ).call

    assert result[:ok], result[:error]
    lesson = @professor.lessons.find_by(classroom: classroom, lesson_date: Date.new(2026, 10, 22))
    assert_equal "Química", lesson.course.name
    assert_equal "Aula de Química", lesson.theme
  end
end
