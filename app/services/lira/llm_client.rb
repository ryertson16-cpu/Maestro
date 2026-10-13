require "json"
require "net/http"
require "uri"

module Lira
  class LlmClient
    def initialize(toolkit)
      @toolkit = toolkit
    end

    def reply(text, history: [])
      messages = [
        { role: "system", content: system_prompt },
        *history,
        { role: "user", content: text }
      ]

      4.times do
        payload = request(messages)
        return nil if payload.blank?

        message = payload.dig("choices", 0, "message")
        return nil if message.blank?

        tool_calls = message["tool_calls"]
        if tool_calls.present?
          messages << message
          tool_calls.each do |call|
            arguments = parse_arguments(call.dig("function", "arguments"))
            result = @toolkit.call(call.dig("function", "name"), arguments)
            messages << {
              role: "tool",
              tool_call_id: call["id"],
              content: result.to_json
            }
          end
          next
        end

        content = message["content"].to_s.strip
        return content if content.present?
      end

      nil
    rescue StandardError => error
      Rails.logger.warn("[Lira] LLM: #{error.class} #{error.message}")
      nil
    end

    private

    def system_prompt
      Lira::Scope.system_prompt(professor: @toolkit.professor)
    end

    def request(messages)
      uri = URI.parse(Lira.openai_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.read_timeout = 30
      http.open_timeout = 10

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{Lira.openai_api_key}"
      request["Content-Type"] = "application/json"
      request.body = {
        model: Lira.openai_model,
        messages: messages,
        tools: @toolkit.definitions,
        temperature: 0.3
      }.to_json

      response = http.request(request)
      return unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def parse_arguments(raw)
      return {} if raw.blank?

      parsed = JSON.parse(raw)
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end
  end
end
