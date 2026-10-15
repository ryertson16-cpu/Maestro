require "test_helper"

class MarketingControllerTest < ActionDispatch::IntegrationTest
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "visitante vê a vitrine em /" do
    get root_path

    assert_response :success
    assert_includes response.body, "O caderno que"
    assert_includes response.body, "Criar conta"
    assert_includes response.body, "SIAGE"
    assert_includes response.body, "fonts.googleapis.com"
    assert_includes response.body, "family=Inter"
    assert_includes response.body, "family=Outfit"
  end
end
