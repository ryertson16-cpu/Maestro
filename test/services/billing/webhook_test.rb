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
    assert subscription.current_period_end > Time.current
  end
end
