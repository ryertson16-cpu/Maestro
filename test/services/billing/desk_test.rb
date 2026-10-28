require "test_helper"

class Billing::DeskTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @owner = Professor.create!(
      name: "Dono",
      email: "desk-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123",
      platform_admin: true
    )
    @teacher = Professor.create!(
      name: "Ana",
      email: "desk-ana-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "summary counts trial accounts" do
    summary = Billing::Desk.new.summary

    assert summary[:professors] >= 2
    assert summary[:trialing] >= 1
  end

  test "activate marks monthly locally" do
    Billing::Desk.new.apply!(@teacher, intent: "activate", actor: @owner)

    subscription = @teacher.subscription.reload
    assert_equal "active", subscription.status
    assert_equal "monthly", subscription.plan
    assert subscription.last_payment_at.present?
  end
end
