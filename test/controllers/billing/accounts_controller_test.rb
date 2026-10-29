require "test_helper"

class Billing::AccountsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @previous = ENV["MAESTRO_BILLING_ENFORCED"]
    ENV["MAESTRO_BILLING_ENFORCED"] = "true"
    @professor = Professor.create!(
      name: "Ana",
      email: "bill-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  teardown do
    ENV["MAESTRO_BILLING_ENFORCED"] = @previous
  end

  test "caderno bloqueado manda para a assinatura" do
    @professor.subscription.update!(
      status: "canceled",
      trial_ends_at: 3.days.ago,
      current_period_end: 3.days.ago
    )
    sign_in @professor

    get root_path

    assert_redirected_to assinatura_path
  end

  test "assinatura vencida ainda abre a tela de plano" do
    @professor.subscription.update!(status: "canceled", current_period_end: 3.days.ago)
    sign_in @professor

    get assinatura_path

    assert_response :success
    assert_includes response.body, "R$"
    assert_includes response.body, "Assinar com PIX"
    assert_includes response.body, "Assinar com cartão"
  end
end
