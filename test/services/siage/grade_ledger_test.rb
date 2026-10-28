require "test_helper"

class Siage::GradeLedgerTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "siage-ledger-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = @professor.grade_levels.create!(name: "3º ano")
    @classroom = @professor.classrooms.create!(
      name: "3ª P",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @student = @professor.students.create!(name: "Ana")
    Enrollment.create!(
      professor: @professor,
      classroom: @classroom,
      student: @student,
      enrolled_on: Date.new(2026, 2, 2),
      status: "active"
    )
  end

  test "lists scored group work including desfile civico as a SIAGE unit" do
    activity = create_activity("Desfile Cívico", "Trabalho em grupo", 3)
    ActivitySubmission.create!(
      activity: activity,
      student: @student,
      professor: @professor,
      score: 8.0,
      submitted_on: Date.new(2026, 9, 3)
    )

    rows = Siage::GradeLedger.new(professor: @professor).rows
    row = rows.find { |item| item.classroom == @classroom && item.bimester == 3 }

    assert row
    assert_equal [ "Desfile Cívico" ], row.unit_titles

    payload = Siage::PayloadBuilder.for_grades(
      professor: @professor,
      classroom: @classroom,
      bimester: 3
    )
    assert_equal 8.0, payload[:grades].first[:units].first[:score]
    assert_equal "Desfile Cívico", payload[:grades].first[:units].first[:activity_title]
  end

  test "counts any scored activity type except project" do
    activity = create_activity("Lista de genética", "Lista de exercícios", 3)
    ActivitySubmission.create!(
      activity: activity,
      student: @student,
      professor: @professor,
      score: 6.5,
      submitted_on: Date.new(2026, 9, 3)
    )

    rows = Siage::GradeLedger.new(professor: @professor).rows
    row = rows.find { |item| item.classroom == @classroom && item.bimester == 3 }

    assert_equal [ "Lista de genética" ], row.unit_titles
  end

  test "sends the first three scored activities by due date" do
    %w[Uma Duas Três Quatro].each_with_index do |title, index|
      activity = create_activity(
        title,
        "Lista de exercícios",
        3,
        due_date: Date.new(2026, 9, 1) + index
      )
      ActivitySubmission.create!(
        activity: activity,
        student: @student,
        professor: @professor,
        score: 7.0,
        submitted_on: Date.new(2026, 9, 1) + index
      )
    end

    titles = Siage::PayloadBuilder.unit_titles_for(
      Activity.regular.joins(:lesson).where(lessons: { classroom_id: @classroom.id }).order(:due_date)
    )

    assert_equal %w[Uma Duas Três], titles
  end

  test "keeps projects out of SIAGE units" do
    activity = create_activity("Feira de ciências", "Projeto", 3)
    ActivitySubmission.create!(
      activity: activity,
      student: @student,
      professor: @professor,
      score: 9.0,
      submitted_on: Date.new(2026, 9, 3)
    )

    rows = Siage::GradeLedger.new(professor: @professor).rows

    refute rows.any? { |item| item.classroom == @classroom && item.bimester == 3 }
  end

  def create_activity(title, type, bimester, due_date: Date.new(2026, 9, 3))
    lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: due_date,
      theme: title,
      siage_time_slot: "1",
      has_activity: true
    )
    lesson.create_activity!(
      title: title,
      activity_type: type,
      due_date: due_date,
      bimester: bimester,
      weight: 1,
      maximum_score: 10
    )
  end
end
