require "test_helper"

class Siage::ExtensionResultsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "siage-ext-#{SecureRandom.hex(4)}@maestro.test",
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
      lesson_date: Date.new(2026, 10, 8),
      theme: "Célula",
      siage_time_slot: "1,2"
    )
  end

  test "rejects a request without token or session" do
    post siage_extension_result_path, params: {
      lesson_ids: [ @lesson.id ],
      status: "verified"
    }, as: :json

    assert_response :unauthorized
    assert_equal 0, SiageShipment.where(lesson: @lesson).count
  end

  test "marks the lesson as verified with the spreadsheet token" do
    token = Siage::ExtensionToken.generate(@professor)

    post siage_extension_result_path,
         params: {
           lesson_ids: [ @lesson.id ],
           status: "verified",
           message: "já estava registrada"
         },
         headers: { "X-Maestro-Token" => token },
         as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_equal 1, json["updated"]
    assert_equal "verified", SiageShipment.where(lesson: @lesson).newest.first.status
  end

  test "marks an already registered lesson without counting it as failed" do
    token = Siage::ExtensionToken.generate(@professor)

    post siage_extension_result_path,
         params: {
           lesson_ids: [ @lesson.id ],
           status: "already_registered",
           message: "Já existe um registro com esta mesma data"
         },
         headers: { "X-Maestro-Token" => token },
         as: :json

    assert_response :success
    shipment = SiageShipment.where(lesson: @lesson).newest.first
    assert_equal "already_registered", shipment.status
    assert_equal "Já no SIAGE", shipment.status_label
    assert_equal 0, Siage::Ledger.new(professor: @professor).summary[:failed]
    assert_equal 1, Siage::Ledger.new(professor: @professor).summary[:already_registered]
  end

  test "records grades as partial without treating them as launched" do
    token = Siage::ExtensionToken.generate(@professor)

    post siage_extension_result_path,
         params: {
           kind: "grades",
           classroom_id: @classroom.id,
           bimester: 3,
           status: "partial",
           message: "salvo parcialmente"
         },
         headers: { "X-Maestro-Token" => token },
         as: :json

    assert_response :success
    shipment = SiageShipment.where(professor: @professor, classroom: @classroom, kind: "grades", bimester: 3).newest.first
    assert_equal "partial", shipment.status
    assert_equal "Parcial", shipment.status_label
  end

  test "records launched grades" do
    token = Siage::ExtensionToken.generate(@professor)

    post siage_extension_result_path,
         params: {
           kind: "grades",
           classroom_id: @classroom.id,
           bimester: 3,
           status: "launched"
         },
         headers: { "X-Maestro-Token" => token },
         as: :json

    assert_response :success
    assert_equal "launched", SiageShipment.where(kind: "grades").newest.first.status
  end

  test "marks the lesson as failed" do
    SiageShipment.record!(
      professor: @professor,
      classroom: @classroom,
      lesson: @lesson,
      kind: "lesson",
      status: "exported"
    )
    token = Siage::ExtensionToken.generate(@professor)

    post siage_extension_result_path,
         params: { lesson_ids: [ @lesson.id ], status: "failed" },
         as: :json,
         headers: { "X-Maestro-Token" => token }

    assert_response :success
    assert_equal "failed", SiageShipment.where(lesson: @lesson).newest.first.status
  end

  test "ignores another professor lesson id" do
    other = Professor.create!(
      name: "Bia",
      email: "siage-ext-other-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    grade = other.grade_levels.create!(name: "2º ano")
    classroom = other.classrooms.create!(
      name: "2ª G",
      school_year: 2026,
      grade_level: grade,
      active: true
    )
    other_lesson = other.lessons.create!(
      classroom: classroom,
      lesson_date: Date.new(2026, 10, 8),
      theme: "Outra"
    )
    token = Siage::ExtensionToken.generate(@professor)

    post siage_extension_result_path,
         params: { lesson_ids: [ other_lesson.id ], status: "verified" },
         as: :json,
         headers: { "X-Maestro-Token" => token }

    assert_response :success
    assert_equal 0, JSON.parse(response.body)["updated"]
    assert_equal 0, SiageShipment.where(lesson: other_lesson).count
  end
end
