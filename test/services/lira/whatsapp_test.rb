require "test_helper"

class Lira::WhatsappTest < ActiveSupport::TestCase
  setup do
    @professor = Professor.create!(
      name: "Ana Souza",
      email: "ana-wa-#{SecureRandom.hex(4)}@maestro.test",
      password: "password123",
      password_confirmation: "password123",
      whatsapp_number: "83988887777"
    )
  end

  test "extracts text messages from the meta payload" do
    incoming = Lira::Whatsapp.extract_incoming(meta_payload("ajuda"))

    assert_equal 1, incoming.size
    assert_equal "5583988887777", incoming.first[:wa_id]
    assert_equal "ajuda", incoming.first[:text]
    assert_equal "wamid.abc", incoming.first[:message_id]
  end

  test "calls the same responder as the site chat" do
    captured = nil

    Lira.stub(:whatsapp_enabled?, true) do
      Lira::Whatsapp.stub(:reply, ->(to:, body:) { captured = { to: to, body: body }; true }) do
        Lira::Whatsapp.handle_incoming(
          wa_id: "5583988887777",
          text: "ajuda",
          message_id: "wamid.help"
        )
      end
    end

    assert_equal "5583988887777", captured[:to]
    assert_includes captured[:body], "hoje"
    assert_includes captured[:body], "status"
  end

  test "does not let an unknown number reach another professor" do
    Lira.stub(:whatsapp_enabled?, true) do
      Lira::Whatsapp.stub(:reply, ->(to:, body:) { @unknown = body; true }) do
        Lira::Whatsapp.handle_incoming(
          wa_id: "5583911112222",
          text: "ajuda",
          message_id: "wamid.unknown"
        )
      end
    end

    assert_includes @unknown, "não está vinculado"
    assert_equal 0, @professor.agent_conversations.count
  end

  test "ignores a duplicated whatsapp message id" do
    calls = 0

    Lira.stub(:whatsapp_enabled?, true) do
      Lira::Whatsapp.stub(:reply, ->(**) { calls += 1; true }) do
        Lira::Whatsapp.handle_incoming(wa_id: "5583988887777", text: "ajuda", message_id: "wamid.dup")
        Lira::Whatsapp.handle_incoming(wa_id: "5583988887777", text: "ajuda", message_id: "wamid.dup")
      end
    end

    assert_equal 1, calls
  end

  private

  def meta_payload(text)
    {
      "entry" => [
        {
          "changes" => [
            {
              "value" => {
                "messages" => [
                  {
                    "from" => "5583988887777",
                    "id" => "wamid.abc",
                    "text" => { "body" => text }
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  end
end
