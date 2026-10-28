require "base64"
require "fileutils"
require "json"
require "net/http"
require "uri"

module Lira
  module Brains
    class OpenAi
      def prepare(system:, history:, user:, tools:)
        @tools = tools
        @messages = [
          { role: "system", content: system },
          *history,
          { role: "user", content: user }
        ]
      end

      def analyze_file(path:, prompt:, system:)
        prepared = Enem::PdfPreview.vision_image(path)
        unless prepared
          Rails.logger.warn("[Lira] GPT visão: não consegui transformar o arquivo em imagem (pdftoppm/magick).")
          return
        end

        data = Base64.strict_encode64(File.binread(prepared[:path]))
        @tools = nil
        @timeout = 90
        @messages = [
          { role: "system", content: system },
          {
            role: "user",
            content: [
              { type: "text", text: prompt },
              { type: "image_url", image_url: { url: "data:#{prepared[:mime]};base64,#{data}" } }
            ]
          }
        ]
        turn = complete
        turn && turn[:kind].to_s == "text" ? turn[:content] : nil
      ensure
        FileUtils.remove_entry(prepared[:dir], force: true) if prepared && prepared[:dir]
      end

      def complete
        payload = request
        return if payload.blank?

        message = payload.dig("choices", 0, "message")
        return if message.blank?

        tool_calls = Array(message["tool_calls"])
        if tool_calls.any?
          @messages << message
          return {
            kind: :tools,
            calls: tool_calls.map { |call| normalize_call(call) }
          }
        end

        content = message["content"].to_s.strip
        return { kind: :text, content: content } if content.present?

        nil
      end

      def add_tool_result(id:, name:, result:)
        @messages << {
          role: "tool",
          tool_call_id: id.presence || name.to_s,
          content: JSON.generate(jsonable(result))
        }
      end

      private

      def normalize_call(call)
        {
          id: call["id"],
          name: call.dig("function", "name"),
          arguments: parse_arguments(call.dig("function", "arguments"))
        }
      end

      def parse_arguments(raw)
        return {} if raw.blank?
        return raw if raw.is_a?(Hash)

        parsed = JSON.parse(raw)
        parsed.is_a?(Hash) ? parsed : {}
      rescue JSON::ParserError
        {}
      end

      def jsonable(value)
        case value
        when Hash then value
        when Array then { items: value }
        else { value: value }
        end
      end

      def request
        uri = URI.parse(Lira.openai_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.read_timeout = @timeout || 30
        http.open_timeout = 10

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{Lira.openai_api_key}"
        request["Content-Type"] = "application/json"
        body = {
          model: Lira.openai_model,
          messages: @messages,
          temperature: 0.3
        }
        body[:tools] = @tools if @tools.present?
        request.body = body.to_json

        response = http.request(request)
        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.warn("[Lira] GPT HTTP #{response.code}")
          return
        end

        JSON.parse(response.body)
      end
    end
  end
end
