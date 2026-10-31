require "test_helper"

class CorrectionsPhoneLinkTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  test "unauthorized tunnel log is treated as dead" do
    link = Corrections::PhoneLink.new
    text = <<~LOG
      INF Retrying connection in up to 32s
      ERR Register tunnel error from server side error="Unauthorized: Tunnel not found"
    LOG

    assert link.log_shows_dead_tunnel?(text)
    refute link.log_shows_dead_tunnel?("INF Registered tunnel connection connIndex=0")
  end

  test "public maestro host never starts a cloudflare tunnel" do
    previous = ENV["MAESTRO_PUBLIC_HOST"]
    ENV["MAESTRO_PUBLIC_HOST"] = "https://cadernomaestro.com.br"

    assert Corrections::PhoneLink.skip_tunnel?
  ensure
    ENV["MAESTRO_PUBLIC_HOST"] = previous
  end
end
