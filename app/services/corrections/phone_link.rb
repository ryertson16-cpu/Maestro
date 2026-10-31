require "json"
require "net/http"
require "open3"
require "timeout"
require "uri"

module Corrections
  class PhoneLink
    STATE = Rails.root.join("tmp/correction_phone_link.json")
    LOG = Rails.root.join("tmp/correction_phone_link.log")
    URL_PATTERN = %r{https://[a-z0-9-]+\.trycloudflare\.com}i
    FAIL_COOLDOWN = 120

    def self.url(port: 3000, wait: false)
      new(port: port).url(wait: wait)
    end

    def self.alive_for?(url)
      new.alive_for?(url)
    end

    def self.starting?(port: 3000)
      new(port: port).starting?
    end

    def self.failed?(port: 3000)
      new(port: port).failed?
    end

    def self.restart!(port: 3000)
      new(port: port).restart!
    end

    def initialize(port: 3000)
      @port = port.to_i
    end

    def url(wait: false)
      return if Rails.env.test?
      return if ENV["MAESTRO_PHONE_LINK"] == "0"

      configured = ENV["MAESTRO_PHONE_HOST"].to_s.strip.sub(%r{/\z}, "")
      if configured.present?
        return configured if probe(configured)
        return
      end

      state = read_state
      live = live_url_from(state)
      return live if live.present?

      stop!(state) if running?(state)
      return if recently_failed?(state) && !wait

      start_tunnel(wait_seconds: wait ? 18 : 10)
    end

    def starting?
      return false if Rails.env.test?

      state = read_state
      running?(state) && live_url_from(state).blank? && !log_shows_dead_tunnel?
    end

    def failed?
      return false if Rails.env.test?

      recently_failed?(read_state)
    end

    def restart!
      return if Rails.env.test?

      stop!(read_state)
      write_state({})
      File.write(LOG, "") if File.file?(LOG)
      start_tunnel(wait_seconds: 18)
    end

    def alive_for?(url)
      live_url_from(read_state).to_s.chomp("/") == url.to_s.chomp("/")
    end

    def log_shows_dead_tunnel?(text = nil)
      tail = (text || log_tail).to_s
      tail.match?(/Unauthorized: Tunnel not found|Tunnel not found|Unable to reach the origin service/i)
    end

    private

    def live_url_from(state)
      candidate = state["url"].to_s.presence || url_from_log
      return if candidate.blank?
      return if log_shows_dead_tunnel?
      return candidate if recently_probed?(state, candidate)
      return unless probe(candidate)

      write_state(state.merge("url" => candidate, "probed_at" => Time.now.iso8601, "port" => @port))
      candidate
    end

    def start_tunnel(wait_seconds: 10)
      binary = cloudflared
      unless binary
        write_state("failed_at" => Time.now.iso8601, "error" => "cloudflared ausente")
        return
      end

      FileUtils.mkdir_p(Rails.root.join("tmp"))
      File.write(LOG, "")
      pid = spawn(
        binary, "tunnel", "--no-autoupdate", "--url", "http://127.0.0.1:#{@port}",
        out: LOG.to_s,
        err: LOG.to_s,
        pgroup: true
      )
      Process.detach(pid)
      write_state("pid" => pid, "url" => nil, "port" => @port)

      found = wait_for_url(seconds: wait_seconds)
      if found.present?
        write_state("pid" => pid, "url" => found, "port" => @port, "probed_at" => Time.now.iso8601)
        return found
      end

      write_state("pid" => pid, "url" => nil, "port" => @port, "failed_at" => Time.now.iso8601, "error" => "túnel sem URL")
      nil
    rescue StandardError => error
      Rails.logger.warn("[phone-link] #{error.class}: #{error.message}")
      write_state("failed_at" => Time.now.iso8601, "error" => error.message)
      nil
    end

    def wait_for_url(seconds: 12)
      Timeout.timeout(seconds) do
        loop do
          match = url_from_log
          return match if match.present?

          sleep 0.3
        end
      end
    rescue Timeout::Error, Errno::ENOENT
      nil
    end

    def url_from_log
      return unless File.file?(LOG)

      File.read(LOG).to_s[URL_PATTERN]
    rescue Errno::ENOENT
      nil
    end

    def log_tail
      return "" unless File.file?(LOG)

      File.read(LOG).to_s.lines.last(40).join
    rescue Errno::ENOENT
      ""
    end

    def probe(url)
      uri = URI.parse(url.to_s)
      return false unless uri.is_a?(URI::HTTP) && uri.host.present?

      uri.path = "/up" if uri.path.blank? || uri.path == "/"
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 2
      http.read_timeout = 2
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
      response = http.request_head(uri.request_uri)
      response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
    rescue StandardError
      false
    end

    def recently_probed?(state, url)
      return false unless state["url"].to_s == url.to_s
      stamp = state["probed_at"].to_s
      return false if stamp.blank?

      Time.zone.parse(stamp) > 20.seconds.ago
    rescue ArgumentError, TypeError
      false
    end

    def running?(state)
      pid = state["pid"].to_i
      return false if pid <= 0

      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end

    def stop!(state)
      pid = state["pid"].to_i
      return if pid <= 0

      Process.kill("-TERM", pid)
    rescue Errno::ESRCH, Errno::EPERM, Errno::EINVAL
      begin
        Process.kill("TERM", pid)
      rescue Errno::ESRCH, Errno::EPERM
        nil
      end
    end

    def recently_failed?(state)
      stamp = state["failed_at"].to_s
      return false if stamp.blank?

      Time.zone.parse(stamp) > FAIL_COOLDOWN.seconds.ago
    rescue ArgumentError, TypeError
      false
    end

    def read_state
      return {} unless File.file?(STATE)

      JSON.parse(File.read(STATE))
    rescue JSON::ParserError
      {}
    end

    def write_state(payload)
      File.write(STATE, JSON.pretty_generate(payload))
    end

    def cloudflared
      [
        ENV["CLOUDFLARED"].presence,
        which_cloudflared,
        "/usr/local/bin/cloudflared",
        "/usr/bin/cloudflared",
        "/mnt/c/Program Files/Cloudflare/cloudflared/cloudflared.exe",
        "/mnt/c/Program Files/cloudflared/cloudflared.exe"
      ].compact.find { |path| usable_binary?(path) }
    end

    def which_cloudflared
      out, status = Open3.capture2("command", "-v", "cloudflared")
      return if status.exitstatus != 0

      out.to_s.strip.presence
    rescue StandardError
      nil
    end

    def usable_binary?(path)
      return false if path.blank?
      return File.file?(path) if path.to_s.end_with?(".exe")

      File.executable?(path)
    end
  end
end
