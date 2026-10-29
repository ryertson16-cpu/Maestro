require "test_helper"

class Platform::DeskControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  setup do
    @previous_owners = ENV["MAESTRO_OWNER_EMAILS"]
    @owner = Professor.create!(
      name: "Dono",
      email: "dono-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123",
      platform_admin: true
    )
    @teacher = Professor.create!(
      name: "Ana Souza",
      email: "ana-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  teardown do
    ENV["MAESTRO_OWNER_EMAILS"] = @previous_owners
  end

  test "gestor abre a mesa de venda" do
    sign_in @owner

    get platform_desk_path

    assert_response :success
    assert_includes response.body, "Gestão do Maestro"
    assert_includes response.body, @teacher.email
    assert_includes response.body, "Período de teste"
  end

  test "professor comum nao ve a gestao" do
    sign_in @teacher

    get platform_desk_path

    assert_response :not_found
  end

  test "e-mail da env tambem libera a mesa" do
    guest = Professor.create!(
      name: "Gestor env",
      email: "env-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123"
    )
    ENV["MAESTRO_OWNER_EMAILS"] = guest.email
    sign_in guest

    get platform_desk_path

    assert_response :success
  end

  test "cortesia libera o caderno na mao" do
    sign_in @owner

    patch platform_desk_account_path(@teacher, intent: "complimentary")

    assert_redirected_to platform_desk_path
    assert_equal "complimentary", @teacher.subscription.reload.status
    assert @teacher.reload.maestro_full_access?
  end

  test "encerrar marca a assinatura como encerrada" do
    sign_in @owner

    patch platform_desk_account_path(@teacher, intent: "cancel")

    assert_equal "canceled", @teacher.subscription.reload.status
  end

  test "mensal cartao na mesa" do
    sign_in @owner

    patch platform_desk_account_path(@teacher, intent: "activate", payment_method: "credit_card")

    assert_equal "active", @teacher.subscription.reload.status
    assert_equal "credit_card", @teacher.subscription.payment_method
  end

  test "ficha da conta e nota interna" do
    sign_in @owner

    get platform_desk_professor_path(@teacher)

    assert_response :success
    assert_includes response.body, @teacher.email

    patch platform_desk_professor_note_path(@teacher), params: { management_note: "PIX na escola" }

    assert_redirected_to platform_desk_professor_path(@teacher)
    assert_equal "PIX na escola", @teacher.reload.management_note
  end

  test "csv da mesa" do
    sign_in @owner

    get platform_desk_export_path

    assert_response :success
    assert_includes response.body, "email"
    assert_includes response.body, @teacher.email
  end
end
