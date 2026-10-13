require "test_helper"

class Siage::LedgerTest < ActiveSupport::TestCase
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
    grade = @professor.grade_levels.create!(name: "2º ano")
    @classroom = @professor.classrooms.create!(
      name: "2ª F",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    @lesson = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.current,
      theme: "Célula"
    )
  end

  test "download queues a lesson instead of treating it as conferido" do
    shipment = SiageShipment.record!(
      professor: @professor,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      filename: "aula.csv"
    )

    assert_equal "exported", shipment.status
    assert_equal "Na fila", shipment.status_label
  end

  test "download does not overwrite already registered" do
    SiageShipment.record!(
      professor: @professor,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      status: "already_registered"
    )

    shipment = SiageShipment.record!(
      professor: @professor,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      filename: "aula.csv"
    )

    assert_equal "already_registered", shipment.status
    assert_equal "Já no SIAGE", shipment.status_label
  end

  test "download does not overwrite conferido" do
    SiageShipment.record!(
      professor: @professor,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      status: "verified"
    )

    shipment = SiageShipment.record!(
      professor: @professor,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      filename: "aula.csv"
    )

    assert_equal "verified", shipment.status
    assert_equal 1, SiageShipment.where(lesson: @lesson).count
  end

  test "download after a failure puts the lesson back in the queue" do
    SiageShipment.record!(
      professor: @professor,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      status: "failed"
    )

    shipment = SiageShipment.record!(
      professor: @professor,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      filename: "aula.csv"
    )

    assert_equal "exported", shipment.status
  end

  test "open lessons skip conferido and already on SIAGE" do
    other = @professor.lessons.create!(
      classroom: @classroom,
      lesson_date: Date.yesterday,
      theme: "Outra"
    )
    SiageShipment.record!(
      professor: @professor,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      status: "verified"
    )
    SiageShipment.record!(
      professor: @professor,
      classroom: @classroom,
      lesson: other,
      kind: "lesson",
      status: "already_registered"
    )

    assert_empty Siage::Ledger.new(professor: @professor).open_lessons
  end

  test "summary folds queued downloads into pendentes" do
    SiageShipment.record!(
      professor: @professor,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson"
    )

    summary = Siage::Ledger.new(professor: @professor).summary

    assert_equal 1, summary[:pending]
    assert_equal 1, summary[:queued]
    assert_equal 0, summary[:verified]
  end
end
