require "json"
require "open3"
require "timeout"

module Corrections
  class PhoneLink
    STATE = Rails.root.join("tmp/correction_phone_link.json")
    LOG = Rails.root.join("tmp/correction_phone_link.log")
    URL_PATTERN = %r{https://[a-z0-9-]+\.trycloudflare\.com}i
    FAIL_COOLDOWN = 120

    def self.url(port: 3000)
      new(port: port).url
    end

    def self.alive_for?(url)
      new.alive_for?(url)
    end

    def self.starting?(port: 3000)
      new(port: port).starting?
    end

    def initialize(port: 3000)
      @port = port.to_i
    end

    def url
      return if Rails.env.test?
      return if ENV["MAESTRO_PHONE_LINK"] == "0"

      configured = ENV["MAESTRO_PHONE_HOST"].to_s.strip.sub(%r{/\z}, "")
      return configured if configured.present?

      state = read_state
      return state["url"] if running?(state) && state["url"].present?

      if running?(state)
        found = url_from_log
        if found.present?
          write_state(state.merge("url" => found, "port" => @port))
          return found
        end
        return nil
      end

      return if recently_failed?(state)

      start_tunnel
    end

    def starting?
      return false if Rails.env.test?

      state = read_state
      running?(state) && state["url"].blank?
    end

    def alive_for?(url)
      state = read_state
      running?(state) && state["url"].to_s.chomp("/") == url.to_s.chomp("/")
    end

    private

    def start_tunnel
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

      found = wait_for_url(seconds: 4)
      write_state("pid" => pid, "url" => found, "port" => @port) if found
      found
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

    def running?(state)
      pid = state["pid"].to_i
      return false if pid <= 0

      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
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
