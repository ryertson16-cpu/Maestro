require "socket"
require "timeout"
require "open3"

module CorrectionHost
  extend ActiveSupport::Concern

  WINDOWS_IPCONFIG = "/mnt/c/Windows/System32/ipconfig.exe"
  WINDOWS_POWERSHELL = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

  included do
    if respond_to?(:helper_method)
      helper_method :correction_host,
                    :localhost_correction_host?,
                    :lan_reachable_host,
                    :reachable_correction_hosts,
                    :phone_unreachable_correction_host?,
                    :automatic_phone_link?
    end
  end

  def correction_host
    remembered = session[:correction_host].to_s.sub(%r{/\z}, "")
    if remembered.present? && usable_correction_host?(remembered)
      return remembered
    end

    host = (Corrections::PhoneLink.url(port: request.port) || lan_reachable_host).to_s.sub(%r{/\z}, "")
    session[:correction_host] = host if host.present?
    host
  end

  def store_correction_host
    raw = params[:correction_host].to_s.strip
    return if raw.blank?

    session[:correction_host] = raw.sub(%r{/g/.*\z}, "").sub(%r{/\z}, "")
  end

  def usable_correction_host?(url)
    uri = URI.parse(url)
    host = uri.host.to_s
    return false if host.blank?
    return true if trycloudflare_host?(host) && Corrections::PhoneLink.alive_for?(url)

    Rails.cache.delete(windows_ip_cache_key)
    phone_reachable_ips.include?(host)
  rescue URI::InvalidURIError
    false
  end

  def trycloudflare_host?(host)
    host.to_s.end_with?(".trycloudflare.com")
  end

  def gabarito_public_url(activity)
    activity.ensure_correction_token!
    "#{correction_host}/g/#{activity.correction_token}"
  end

  def gabarito_student_url(activity, student)
    "#{gabarito_public_url(activity)}/a/#{student.id}"
  end

  def localhost_correction_host?
    virtual_ip?(URI.parse(correction_host.to_s).host.to_s) ||
      %w[localhost 127.0.0.1 0.0.0.0].include?(URI.parse(correction_host.to_s).host.to_s)
  rescue URI::InvalidURIError
    false
  end

  def phone_unreachable_correction_host?
    return false if automatic_phone_link?

    localhost_correction_host?
  end

  def automatic_phone_link?
    trycloudflare_host?(URI.parse(correction_host.to_s).host.to_s)
  rescue URI::InvalidURIError
    false
  end

  def lan_reachable_host
    reachable_correction_hosts.first || request.base_url
  end

  def reachable_correction_hosts
    port = request.port
    suffix = [80, 443].include?(port.to_i) ? "" : ":#{port}"
    scheme = request.scheme
    phone_reachable_ips.map { |ip| "#{scheme}://#{ip}#{suffix}" }
  end

  def phone_reachable_ips
    (windows_lan_ips + local_ipv4_addresses)
      .uniq
      .reject { |ip| virtual_ip?(ip) }
      .sort_by { |ip| ip_rank(ip) }
  end

  def local_ipv4_addresses
    Socket.ip_address_list.filter_map do |addr|
      next unless addr.ipv4? && !addr.ipv4_loopback?

      addr.ip_address
    end
  end

  def windows_lan_ips
    return [] if Rails.env.test?
    return [] unless File.exist?(WINDOWS_IPCONFIG)

    cached = Rails.cache.read(windows_ip_cache_key)
    return cached if cached.present?

    ips = read_windows_lan_ips
    Rails.cache.write(windows_ip_cache_key, ips, expires_in: 20.seconds) if ips.any?
    ips
  rescue StandardError
    []
  end

  def read_windows_lan_ips
    from_ipconfig = ips_from_ipconfig(ipconfig_text)
    return from_ipconfig if from_ipconfig.any?

    powershell_gateway_ips
  end

  def powershell_gateway_ips
    return [] unless File.exist?(WINDOWS_POWERSHELL)

    text = Timeout.timeout(12) do
      out, = Open3.capture2(
        WINDOWS_POWERSHELL,
        "-NoProfile",
        "-Command",
        "Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null } | ForEach-Object { $_.IPv4Address.IPAddress }"
      )
      out
    end
    normalize_text(text).scan(/\b(\d{1,3}(?:\.\d{1,3}){3})\b/).flatten.reject { |ip| virtual_ip?(ip) }
  rescue StandardError
    []
  end

  def ipconfig_text
    Timeout.timeout(4) do
      out, = Open3.capture2(WINDOWS_IPCONFIG)
      out
    end
  rescue StandardError
    ""
  end

  def ips_from_ipconfig(text)
    normalize_text(text).split(/Adaptador /i).filter_map do |block|
      next if /desconectad|disconnected|WSL|vEthernet|VPN|Bluetooth|Loopback/i.match?(block)

      ip = block[/(?:IPv4)[^\d]{0,80}([\d.]+)/, 1]
      next unless ip
      next if virtual_ip?(ip)

      gateways = block.scan(/Gateway[^\d]{0,40}([\d.]+)/).flatten
      has_gateway = gateways.any? { |gw| gw.count(".") == 3 && gw != "0.0.0.0" }
      ip if has_gateway || ip.start_with?("192.168.")
    end
  end

  def normalize_text(text)
    text.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
  end

  def virtual_ip?(ip)
    ip = ip.to_s
    ip.start_with?("127.", "169.254.", "10.255.255.") ||
      ip.match?(/\A172\.(1[6-9]|2\d|3[0-1])\./) ||
      %w[localhost 0.0.0.0].include?(ip)
  end

  def ip_rank(ip)
    return 0 if ip.start_with?("192.168.")
    return 1 if ip.start_with?("10.")

    2
  end

  def windows_ip_cache_key
    "maestro/windows_lan_ips"
  end
end
