require "test_helper"

class LegalControllerTest < ActionDispatch::IntegrationTest
  test "company page is public" do
    get "/empresa"

    assert_response :success
    assert_includes response.body, "Maestro 2.0"
    assert_includes response.body, "Ryertson Nogueira da Silva"
    assert_includes response.body, "+55 84 99118-4774"
  end
end
