require "test_helper"

class Siage::RostersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "roster-ui-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in @professor
  end

  test "open page exposes roster handoff" do
    get siage_roster_path

    assert_response :success
    assert_includes response.body, "maestro-siage-handoff"
    assert_includes response.body, "Ler turmas no SIAGE"
    payload = JSON.parse(css_handoff)
    assert_equal "roster", payload["mode"]
    assert_equal "roster", payload.dig("job", "kind")
  end

  test "extension posts roster for review then apply creates classroom" do
    token = Siage::ExtensionToken.generate(@professor)

    post siage_extension_roster_path,
         params: {
           classrooms: [
             {
               name: "2ª SÉRIE F",
               componente: "Ciências",
               turma_id: "abc-1",
               students: [ { name: "Maria Silva" } ]
             }
           ]
         },
         headers: { "X-Maestro-Token" => token },
         as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_equal "pending_review", json["status"]

    get siage_roster_path
    assert_response :success
    assert_includes response.body, "Maria Silva"
    assert_includes response.body, "Gravar no caderno"

    assert_difference -> { @professor.classrooms.count }, 1 do
      post apply_siage_roster_path
    end
    assert_redirected_to siage_roster_compare_path
    assert @professor.classrooms.find_by(name: "2ª F").students.exists?(name: "Maria Silva")
  end

  test "compare lists student enrolled in the wrong classroom" do
    grade = @professor.grade_levels.create!(name: "2º ano", active: true)
    sala_h = @professor.classrooms.create!(name: "2ª H", school_year: Date.current.year, grade_level: grade, active: true)
    sala_f = @professor.classrooms.create!(name: "2ª F", school_year: Date.current.year, grade_level: grade, active: true)
    aluno = @professor.students.create!(name: "Alerrandro Vitor da Silva Alves")
    Enrollment.create!(professor: @professor, student: aluno, classroom: sala_h, enrolled_on: Date.current, status: "active")

    @professor.siage_roster_imports.create!(
      status: "applied",
      applied_at: Time.current,
      payload: {
        "classrooms" => [
          {
            "name" => "2ª SÉRIE F",
            "componente" => "Ciências",
            "students" => [ { "name" => "Alerrandro Vitor da Silva Alves" } ]
          }
        ]
      }
    )

    get siage_roster_compare_path
    assert_response :success
    assert_includes response.body, "Alerrandro Vitor da Silva Alves"
    assert_includes response.body, "2ª H"
    assert_includes response.body, "Mover para 2ª F"

    enrollment = aluno.enrollments.find_by!(status: "active")
    patch move_siage_roster_student_path(enrollment, classroom_id: sala_f.id)
    assert_redirected_to siage_roster_compare_path
    assert_equal "finished", enrollment.reload.status
    assert sala_f.enrollments.where(status: "active").exists?(student: aluno)
  end


  test "rejects roster post without token" do
    sign_out @professor
    post siage_extension_roster_path, params: { classrooms: [] }, as: :json

    assert_response :unauthorized
  end

  private

  def css_handoff
    match = response.body.match(%r{<script type="application/json" id="maestro-siage-handoff">(.*?)</script>}m)
    flunk "missing handoff" unless match
    match[1]
  end
end
