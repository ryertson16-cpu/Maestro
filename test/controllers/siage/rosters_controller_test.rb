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
    assert_redirected_to classrooms_path
    assert @professor.classrooms.find_by(name: "2ª F").students.exists?(name: "Maria Silva")
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
