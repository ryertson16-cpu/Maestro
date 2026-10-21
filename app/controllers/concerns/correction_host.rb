require "socket"

module CorrectionHost
  extend ActiveSupport::Concern

  included do
    helper_method :correction_host, :localhost_correction_host?, :lan_reachable_host
  end

  def correction_host
    session[:correction_host].presence || lan_reachable_host
  end

  def store_correction_host
    raw = params[:correction_host].to_s.strip
    return if raw.blank?

    session[:correction_host] = raw.sub(%r{/g/.*\z}, "").sub(%r{/\z}, "")
  end

  def gabarito_public_url(activity)
    activity.ensure_correction_token!
    "#{correction_host}/g/#{activity.correction_token}"
  end

  def gabarito_student_url(activity, student)
    "#{gabarito_public_url(activity)}/a/#{student.id}"
  end

  def localhost_correction_host?
    uri = URI.parse(correction_host.to_s)
    %w[localhost 127.0.0.1 0.0.0.0].include?(uri.host.to_s)
  rescue URI::InvalidURIError
    false
  end

  def lan_reachable_host
    host = request.host.to_s
    return request.base_url unless %w[localhost 127.0.0.1 0.0.0.0].include?(host)

    ip = Socket.ip_address_list.find { |addr| addr.ipv4? && !addr.ipv4_loopback? }&.ip_address
    return request.base_url if ip.blank?

    port = request.port
    suffix = [80, 443].include?(port.to_i) ? "" : ":#{port}"
    "#{request.scheme}://#{ip}#{suffix}"
  end
end
