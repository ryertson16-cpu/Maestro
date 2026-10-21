require "test_helper"

class Lira::WhatsappWebhooksControllerTest < ActionDispatch::IntegrationTest
  test "verifies the meta webhook subscription" do
    token = "maestro-lira-verify"
    Lira.stub(:whatsapp_verify_token, token) do
      get "/whatsapp/webhook",
          params: {
            "hub.mode" => "subscribe",
            "hub.verify_token" => token,
            "hub.challenge" => "challenge-123"
          }
    end

    assert_response :success
    assert_equal "challenge-123", response.body
  end

  test "rejects a wrong verify token" do
    Lira.stub(:whatsapp_verify_token, "certo") do
      get "/whatsapp/webhook",
          params: {
            "hub.mode" => "subscribe",
            "hub.verify_token" => "errado",
            "hub.challenge" => "challenge-123"
          }
    end

    assert_response :forbidden
  end

  test "enqueues the lira job and returns ok" do
    payload = {
      entry: [
        {
          changes: [
            {
              value: {
                messages: [
                  {
                    from: "5583988887777",
                    id: "wamid.xyz",
                    text: { body: "hoje" }
                  }
                ]
              }
            }
          ]
        }
      ]
    }

    assert_enqueued_with(job: Lira::ProcessWhatsappJob) do
      post "/whatsapp/webhook", params: payload, as: :json
    end

    assert_response :ok
  end
end
