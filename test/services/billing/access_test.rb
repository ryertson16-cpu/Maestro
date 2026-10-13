require "test_helper"

class Billing::AccessTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @previous = ENV["MAESTRO_BILLING_ENFORCED"]
    ENV["MAESTRO_BILLING_ENFORCED"] = "true"
    @professor = Professor.create!(
      name: "Ana",
      email: "ana-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  teardown do
    ENV["MAESTRO_BILLING_ENFORCED"] = @previous
  end

  test "trial recém-criado libera o caderno" do
    assert_equal "trialing", @professor.subscription.status
    assert Billing::Access.allowed?(@professor)
  end

  test "assinatura vencida bloqueia" do
    @professor.subscription.update!(
      status: "canceled",
      trial_ends_at: 2.days.ago,
      current_period_end: 2.days.ago
    )

    refute Billing::Access.allowed?(@professor)
  end

  test "cortesia sempre libera" do
    @professor.subscription.update!(status: "complimentary", plan: "complimentary")
    assert Billing::Access.allowed?(@professor)
  end

  test "sem cobrança forçada, libera mesmo cancelado" do
    ENV["MAESTRO_BILLING_ENFORCED"] = "false"
    @professor.subscription.update!(status: "canceled")
    assert Billing::Access.allowed?(@professor)
  end
end
