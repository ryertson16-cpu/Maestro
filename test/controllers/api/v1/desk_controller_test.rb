require "test_helper"

class Api::V1::DeskControllerTest < ActionDispatch::IntegrationTest
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @token = "desk-test-token"
    ENV["MAESTRO_DESK_API_TOKEN"] = @token
    @professor = Professor.create!(
      name: "Ana Souza",
      preferred_name: "Ana",
      email: "desk-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123",
      whatsapp_number: "83988887777"
    )
  end

  teardown do
    ENV.delete("MAESTRO_DESK_API_TOKEN")
  end

  test "rejects missing token" do
    get "/api/v1/desk/health"

    assert_response :unauthorized
  end

  test "health with bearer token" do
    get "/api/v1/desk/health", headers: auth

    assert_response :success
    assert JSON.parse(response.body)["ok"]
  end

  test "finds a professor by whatsapp" do
    get "/api/v1/desk/professor", params: { whatsapp: "5583988887777" }, headers: auth

    assert_response :success
    body = JSON.parse(response.body)
    assert body["found"]
    assert_equal "Ana", body["greeting_name"]
    assert body.dig("subscription", "label").present?
    refute_includes body.keys, "siage_password"
  end

  test "records an inbound message and links the account" do
    post "/api/v1/desk/messages",
         params: {
           whatsapp: "83988887777",
           name: "Ana",
           text: "Quero assinar o Maestro",
           intent: "sales",
           direction: "inbound"
         },
         as: :json,
         headers: auth

    assert_response :created
    body = JSON.parse(response.body)
    assert body["ok"]
    assert_equal @professor.id, body["professor_id"]
    assert_equal "Quero assinar o Maestro", DeskMessage.last.body
  end

  private

  def auth
    { "Authorization" => "Bearer #{@token}" }
  end
end
