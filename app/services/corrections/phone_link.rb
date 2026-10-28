require "json"
require "timeout"

module Corrections
  class PhoneLink
    STATE = Rails.root.join("tmp/correction_phone_link.json")
    LOG = Rails.root.join("tmp/correction_phone_link.log")
    URL_PATTERN = %r{https://[a-z0-9-]+\.trycloudflare\.com}i

    def self.url(port: 3000)
      new(port: port).url
    end

    def self.alive_for?(url)
      new.alive_for?(url)
    end

    def initialize(port: 3000)
      @port = port.to_i
    end

    def url
      return if Rails.env.test?
      return if ENV["MAESTRO_PHONE_LINK"] == "0"

      state = read_state
      return state["url"] if running?(state) && state["url"].present?

      start_tunnel
    end

    def alive_for?(url)
      state = read_state
      running?(state) && state["url"].to_s.chomp("/") == url.to_s.chomp("/")
    end

    private

    def start_tunnel
      binary = cloudflared
      return if binary.blank?

      FileUtils.mkdir_p(Rails.root.join("tmp"))
      File.write(LOG, "")
      pid = spawn(
        binary, "tunnel", "--no-autoupdate", "--url", "http://127.0.0.1:#{@port}",
        out: LOG.to_s,
        err: LOG.to_s,
        pgroup: true
      )
      Process.detach(pid)
      found = wait_for_url
      write_state("pid" => pid, "url" => found, "port" => @port) if found
      found
    rescue StandardError => error
      Rails.logger.warn("[phone-link] #{error.class}: #{error.message}")
      nil
    end

    def wait_for_url
      Timeout.timeout(12) do
        loop do
          match = File.read(LOG).to_s[URL_PATTERN]
          return match if match.present?

          sleep 0.3
        end
      end
    rescue Timeout::Error, Errno::ENOENT
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
        "/usr/local/bin/cloudflared",
        "/usr/bin/cloudflared"
      ].compact.find { |path| File.executable?(path) }
    end
  end
end
