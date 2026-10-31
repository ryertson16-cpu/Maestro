require "test_helper"

class CorrectionHostIpTest < ActiveSupport::TestCase
  def load_fixtures(_config = ActiveRecord::Base)
    {}
  end

  class Probe
    include CorrectionHost
  end

  test "ipconfig parser keeps wifi address with gateway and drops wsl" do
    text = <<~TEXT
      Adaptador Ethernet vEthernet (WSL (Hyper-V firewall)):
         Endereço IPv4. . . . . . . .  . . . . . . . : 172.17.32.1
         Gateway Padrão. . . . . . . . . . . . . . . :

      Adaptador de Rede sem Fio Wi-Fi:
         Endereço IPv4. . . . . . . .  . . . . . . . : 192.168.1.36
         Gateway Padrão. . . . . . . . . . . . . . . : 192.168.1.1
    TEXT

    ips = Probe.new.ips_from_ipconfig(text)

    assert_equal [ "192.168.1.36" ], ips
  end

  test "drops a wifi address that is no longer on this computer" do
    probe = Probe.new
    def probe.phone_reachable_ips
      [ "192.168.0.20" ]
    end

    refute probe.usable_correction_host?("http://192.168.1.36:3000")
    assert probe.usable_correction_host?("http://192.168.0.20:3000")
  end

  test "https tunnel replaces a remembered lan address" do
    probe = Probe.new
    chosen = probe.pick_correction_host(
      tunnel: "https://gabarito.trycloudflare.com",
      remembered: "http://10.25.151.233:3000",
      lan: "http://10.25.151.233:3000"
    )

    assert_equal "https://gabarito.trycloudflare.com", chosen
  end

  test "http lan address is not used for the phone qr" do
    probe = Probe.new
    chosen = probe.pick_correction_host(
      tunnel: "",
      remembered: "http://10.25.151.233:3000",
      lan: "http://10.25.151.233:3000"
    )

    assert_nil chosen
  end

  test "virtual ips are not offered to the phone" do
    probe = Probe.new

    assert probe.virtual_ip?("10.255.255.254")
    assert probe.virtual_ip?("172.17.40.213")
    refute probe.virtual_ip?("192.168.1.36")
  end
end
