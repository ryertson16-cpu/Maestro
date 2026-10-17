require "json"
require "net/http"
require "uri"

module Lira
  module Brains
    class Gemini
      TYPE_MAP = {
        "object" => "OBJECT",
        "string" => "STRING",
        "integer" => "INTEGER",
        "number" => "NUMBER",
        "boolean" => "BOOLEAN",
        "array" => "ARRAY"
      }.freeze

      def prepare(system:, history:, user:, tools:)
        @system = system
        @tools = gemini_tools(tools)
        @contents = history_contents(history)
        @contents << { role: "user", parts: [{ text: user.to_s }] }
      end

      def complete
        payload = request
        return if payload.blank?

        parts = Array(payload.dig("candidates", 0, "content", "parts"))
        calls = parts.filter_map { |part| normalize_call(part["functionCall"] || part["function_call"]) }

        if calls.any?
          @contents << { role: "model", parts: parts }
          return { kind: :tools, calls: calls }
        end

        content = parts.filter_map { |part| part["text"] }.join.strip
        return { kind: :text, content: content } if content.present?

        nil
      end

      def add_tool_result(id:, name:, result:)
        @contents << {
          role: "user",
          parts: [
            {
              functionResponse: {
                name: name.to_s,
                response: stringify_keys(jsonable(result))
              }
            }
          ]
        }
      end

      def gemini_tools(openai_tools)
        declarations = Array(openai_tools).filter_map do |item|
          function = item[:function] || item["function"] || item
          name = function[:name] || function["name"]
          next if name.blank?

          parameters = function[:parameters] || function["parameters"] || {}
          {
            name: name,
            description: function[:description] || function["description"],
            parameters: gemini_schema(parameters)
          }
        end

        return [] if declarations.empty?

        [{ functionDeclarations: declarations }]
      end

      private

      def history_contents(history)
        Array(history).filter_map do |message|
          role = (message[:role] || message["role"]).to_s
          content = (message[:content] || message["content"]).to_s
          next if content.blank?
          next if role == "system"

          {
            role: role == "assistant" ? "model" : "user",
            parts: [{ text: content }]
          }
        end
      end

      def normalize_call(raw)
        return if raw.blank?

        name = raw["name"] || raw[:name]
        return if name.blank?

        arguments = raw["args"] || raw[:args] || raw["arguments"] || {}
        {
          id: "#{name}-#{SecureRandom.hex(4)}",
          name: name,
          arguments: arguments.is_a?(Hash) ? arguments : {}
        }
      end

      def gemini_schema(schema)
        hash = schema.to_h
        type = (hash[:type] || hash["type"]).to_s.downcase
        properties = hash[:properties] || hash["properties"] || {}
        required = hash[:required] || hash["required"] || []

        converted = { type: TYPE_MAP.fetch(type, "OBJECT") }
        if properties.present?
          converted[:properties] = properties.to_h.to_h do |key, value|
            [key.to_s, gemini_schema(value)]
          end
        end
        converted[:required] = Array(required).map(&:to_s) if required.present?
        converted[:description] = hash[:description] || hash["description"] if (hash[:description] || hash["description"]).present?
        converted
      end

      def jsonable(value)
        case value
        when Hash then value
        when Array then { items: value }
        else { value: value }
        end
      end

      def stringify_keys(value)
        case value
        when Hash
          value.to_h.stringify_keys.transform_values { |item| stringify_keys(item) }
        when Array
          value.map { |item| stringify_keys(item) }
        else
          value
        end
      end

      def request
        uri = URI.parse(Lira.gemini_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.read_timeout = 30
        http.open_timeout = 10

        request = Net::HTTP::Post.new(uri)
        request["x-goog-api-key"] = Lira.gemini_api_key
        request["Content-Type"] = "application/json"
        request.body = {
          systemInstruction: { parts: [{ text: @system }] },
          contents: @contents,
          tools: @tools,
          generationConfig: { temperature: 0.3 }
        }.to_json

        response = http.request(request)
        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.warn("[Lira] Gemini HTTP #{response.code}")
          return
        end

        JSON.parse(response.body)
      end
    end
  end
end
