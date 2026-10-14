require "test_helper"

class Lira::PhoneTest < ActiveSupport::TestCase
  test "matches numbers with and without country code" do
    assert Lira::Phone.match?("83999998888", "5583999998888")
    assert Lira::Phone.match?("5583999998888", "(83) 99999-8888")
    refute Lira::Phone.match?("83999998888", "83988887777")
  end

  test "matches brazilian mobile when Meta omits the extra 9" do
    assert Lira::Phone.match?("84991184774", "558491184774")
    assert Lira::Phone.match?("5584991184774", "558491184774")
  end

  test "formats brazil numbers for the cloud api" do
    assert_equal "5583999998888", Lira::Phone.e164("83999998888")
    assert_equal "5583999998888", Lira::Phone.e164("5583999998888")
  end
end
