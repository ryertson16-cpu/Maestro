require "test_helper"

class TimetablesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ryertson Silva",
      preferred_name: "Ryertson",
      email: "grade-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in @professor
  end

  test "shows the empty timetable page" do
    get timetable_path

    assert_response :success
    assert_includes response.body, "Meu horário"
    assert_includes response.body, "Gerar meu horário"
  end

  test "creates lessons for a past week from the saved timetable" do
    grade = @professor.grade_levels.create!(name: "2º ano")
    classroom = @professor.classrooms.create!(
      name: "2ª H",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    course = @professor.courses.create!(
      name: "Química",
      knowledge_area: "ciencias_da_natureza",
      active: true
    )
    @professor.timetable_entries.create!(
      classroom: classroom,
      course: course,
      weekday: 1,
      period: 2,
      time_slot: "2º tempo"
    )
    monday = Date.new(2026, 10, 5)

    post generate_timetable_week_path, params: { week: monday }

    assert_redirected_to timetable_path(week: monday)
    lesson = @professor.lessons.find_by(classroom: classroom, lesson_date: monday, siage_time_slot: "2º tempo")
    assert lesson
    assert_equal course.id, lesson.course_id
  end

  test "creates lessons only for the chosen classroom" do
    grade = @professor.grade_levels.create!(name: "2º ano")
    first = @professor.classrooms.create!(
      name: "2ª H",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    second = @professor.classrooms.create!(
      name: "2ª J",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    course = @professor.courses.create!(
      name: "Química",
      knowledge_area: "ciencias_da_natureza",
      active: true
    )
    [first, second].each do |classroom|
      @professor.timetable_entries.create!(
        classroom: classroom,
        course: course,
        weekday: 1,
        period: 2,
        time_slot: "2º tempo"
      )
    end
    monday = Date.new(2026, 10, 5)

    post generate_timetable_week_path, params: {
      week: monday,
      scope: "classroom",
      classroom_id: first.id
    }

    assert_redirected_to timetable_path(week: monday, scope: "classroom", classroom_id: first.id)
    assert @professor.lessons.exists?(classroom: first, lesson_date: monday)
    assert_not @professor.lessons.exists?(classroom: second, lesson_date: monday)
  end

  test "creates every classroom lesson for a single past day" do
    grade = @professor.grade_levels.create!(name: "2º ano")
    first = @professor.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    second = @professor.classrooms.create!(
      name: "3ª O",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    course = @professor.courses.create!(
      name: "Química",
      knowledge_area: "ciencias_da_natureza",
      active: true
    )
    @professor.timetable_entries.create!(
      classroom: first,
      course: course,
      weekday: 4,
      period: 2,
      time_slot: "2º tempo"
    )
    @professor.timetable_entries.create!(
      classroom: second,
      course: course,
      weekday: 4,
      period: 8,
      time_slot: "8º tempo"
    )
    thursday = Date.new(2026, 10, 22)

    post generate_timetable_day_path, params: { lesson_date: thursday, week: thursday }

    assert_redirected_to timetable_path(week: thursday)
    assert @professor.lessons.exists?(classroom: first, lesson_date: thursday, course: course)
    assert @professor.lessons.exists?(classroom: second, lesson_date: thursday, course: course)
    assert_equal ["Aula de Química"], @professor.lessons.where(lesson_date: thursday).distinct.pluck(:theme)
  end
end

