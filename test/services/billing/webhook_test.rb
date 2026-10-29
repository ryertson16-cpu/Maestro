require "test_helper"

class Billing::WebhookTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @professor = Professor.create!(
      name: "Ana",
      email: "wh-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "pagamento confirmado ativa o mês" do
    Billing::Webhook.new(
      "event" => "PAYMENT_CONFIRMED",
      "payment" => {
        "id" => "pay_1",
        "customer" => "cus_1",
        "subscription" => "sub_1",
        "externalReference" => @professor.id.to_s
      }
    ).process!

    subscription = @professor.subscription.reload
    assert_equal "active", subscription.status
    assert_equal "pix", subscription.payment_method
    assert subscription.current_period_end > Time.current
  end

  test "pagamento no cartao grava a forma" do
    Billing::Webhook.new(
      "event" => "PAYMENT_RECEIVED",
      "payment" => {
        "id" => "pay_card",
        "billingType" => "CREDIT_CARD",
        "customer" => "cus_2",
        "subscription" => "sub_2",
        "externalReference" => @professor.id.to_s
      }
    ).process!

    assert_equal "credit_card", @professor.subscription.reload.payment_method
  end
end
