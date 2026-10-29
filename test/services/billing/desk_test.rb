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
    assert_equal "pix", subscription.payment_method
    assert subscription.last_payment_at.present?
  end

  test "activate with credit card stores payment method" do
    Billing::Desk.new.apply!(
      @teacher,
      intent: "activate",
      actor: @owner,
      payment_method: "credit_card"
    )

    assert_equal "credit_card", @teacher.subscription.reload.payment_method
  end

  test "client segment returns only monthly accounts" do
    Billing::Desk.new.apply!(@teacher, intent: "activate", actor: @owner)

    accounts = Billing::Desk.new.accounts(segment: "client")

    assert_includes accounts, @teacher
    assert_not_includes accounts, @owner
  end
end
