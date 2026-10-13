require "test_helper"

class GradeLevelsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get grade_levels_index_url
    assert_response :success
  end

  test "should get new" do
    get grade_levels_new_url
    assert_response :success
  end

  test "should get create" do
    get grade_levels_create_url
    assert_response :success
  end

  test "should get edit" do
    get grade_levels_edit_url
    assert_response :success
  end

  test "should get update" do
    get grade_levels_update_url
    assert_response :success
  end

  test "should get destroy" do
    get grade_levels_destroy_url
    assert_response :success
  end
end
