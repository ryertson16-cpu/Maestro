require "test_helper"

class SchoolCalendarsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      preferred_name: "Ryertson",
      email: "cal-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    @course = @professor.courses.create!(
      name: "Química",
      knowledge_area: "ciencias_da_natureza",
      active: true
    )
    grade = @professor.grade_levels.create!(name: "2º ano")
    @first = @professor.classrooms.create!(name: "2ª F", school_year: 2026, grade_level: grade, active: true)
    @second = @professor.classrooms.create!(name: "2ª H", school_year: 2026, grade_level: grade, active: true)
    @third = @professor.classrooms.create!(name: "3ª L", school_year: 2026, grade_level: grade, active: true)
    [@first, @second, @third].each_with_index do |classroom, index|
      @professor.timetable_entries.create!(
        classroom: classroom,
        course: @course,
        weekday: 4,
        period: index + 2,
        time_slot: "#{index + 2}º tempo"
      )
    end
    sign_in @professor
  end

  test "calendar lists every classroom slot for the selected thursday" do
    get school_calendar_path(year: 2026, day: "2026-10-22")

    assert_response :success
    assert_includes response.body, "Minhas aulas em"
    assert_includes response.body, "2ª F"
    assert_includes response.body, "2ª H"
    assert_includes response.body, "3ª L"
    assert_includes response.body, "Criar minhas aulas deste dia"
  end

  test "creates delayed lessons for every classroom on the selected day" do
    thursday = Date.new(2026, 10, 22)

    post generate_school_calendar_lessons_path, params: { lesson_date: thursday, year: 2026 }

    assert_redirected_to school_calendar_path(year: 2026, day: thursday)
    assert @professor.lessons.exists?(classroom: @first, lesson_date: thursday, course: @course)
    assert @professor.lessons.exists?(classroom: @second, lesson_date: thursday, course: @course)
    assert @professor.lessons.exists?(classroom: @third, lesson_date: thursday, course: @course)
    assert_equal 3, @professor.lessons.where(lesson_date: thursday).count
  end

  test "pdf import creates the whole thursday not only 2a F" do
    path = Rails.root.join("test/fixtures/files/novo_horario.pdf")
    skip "PDF do horário não está nos fixtures" unless path.exist?

    %w[2ª\ I 3ª\ K 3ª\ M 3ª\ N 3ª\ O].each do |name|
      @professor.classrooms.create!(
        name: name,
        school_year: 2026,
        grade_level: @first.grade_level,
        active: true
      )
    end

    post school_calendar_timetable_lesson_path, params: {
      lesson_date: "2026-10-22",
      timetable: Rack::Test::UploadedFile.new(path, "application/pdf")
    }

    assert_response :success
    body = JSON.parse(response.body)
    assert body["ok"], body["error"]
    thursday = @professor.lessons.where(lesson_date: Date.new(2026, 10, 22)).includes(:classroom, :course)
    assert_operator thursday.count, :>=, 5
    assert thursday.all? { |lesson| lesson.course.name == "Química" }
    names = thursday.map { |lesson| lesson.classroom.name }.join
    %w[F H L M N K].each { |letter| assert_includes names, letter }
  end

  test "imports the SEE calendar file onto the year grid" do
    path = Rails.root.join("test/fixtures/files/see_calendario_pb_2026.pdf")

    post import_school_calendar_see_path, params: {
      file: Rack::Test::UploadedFile.new(path, "application/pdf")
    }

    assert_redirected_to school_calendar_path(year: 2026)
    day = @professor.school_calendar_days.find_by(day: Date.new(2026, 2, 2))
    assert_equal "planning", day.kind
    assert_equal "Formação inicial", day.name
  end

  test "professor can mark a day with a SEE legend" do
    post school_calendar_days_path, params: {
      day: "2026-08-11",
      kind: "JP",
      name: ""
    }

    assert_redirected_to school_calendar_path(year: 2026, day: Date.new(2026, 8, 11))
    day = @professor.school_calendar_days.find_by(day: Date.new(2026, 8, 11))
    assert_equal "planning", day.kind
    assert_equal "Jornada pedagógica", day.name
  end
end

