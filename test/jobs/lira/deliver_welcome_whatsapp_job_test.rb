require "test_helper"

class Lira::DeliverWelcomeWhatsappJobTest < ActiveJob::TestCase
  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "ana-welcome-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123",
      whatsapp_number: "83988887777"
    )
  end

  test "sends welcome and records the timestamp" do
    captured = nil

    Lira.stub(:whatsapp_enabled?, true) do
      Lira::Whatsapp.stub(:reply, ->(to:, body:) { captured = { to: to, body: body }; true }) do
        Lira::DeliverWelcomeWhatsappJob.perform_now(@professor.id)
      end
    end

    assert_equal "5583988887777", captured[:to]
    assert_includes captured[:body], "Ana"
    assert_includes captured[:body], "ajuda"
    assert @professor.reload.whatsapp_welcome_sent_at.present?
  end

  test "does not send twice for the same number" do
    calls = 0

    Lira.stub(:whatsapp_enabled?, true) do
      Lira::Whatsapp.stub(:reply, ->(**) { calls += 1; true }) do
        Lira::DeliverWelcomeWhatsappJob.perform_now(@professor.id)
        Lira::DeliverWelcomeWhatsappJob.perform_now(@professor.id)
      end
    end

    assert_equal 1, calls
  end

  test "sends again after the whatsapp number changes" do
    Lira.stub(:whatsapp_enabled?, true) do
      Lira::Whatsapp.stub(:reply, true) do
        Lira::DeliverWelcomeWhatsappJob.perform_now(@professor.id)
      end
    end

    @professor.update!(whatsapp_number: "83911112222")
    assert @professor.needs_whatsapp_welcome?

    captured = nil
    Lira.stub(:whatsapp_enabled?, true) do
      Lira::Whatsapp.stub(:reply, ->(to:, body:) { captured = to; true }) do
        Lira::DeliverWelcomeWhatsappJob.perform_now(@professor.id)
      end
    end

    assert_equal "5583911112222", captured
  end

  test "skips when the whatsapp api is not configured" do
    Lira.stub(:whatsapp_enabled?, false) do
      Lira::Whatsapp.stub(:reply, ->(**) { flunk "não deveria enviar" }) do
        Lira::DeliverWelcomeWhatsappJob.perform_now(@professor.id)
      end
    end

    assert_nil @professor.reload.whatsapp_welcome_sent_at
  end
end
