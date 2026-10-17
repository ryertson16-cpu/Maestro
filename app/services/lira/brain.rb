module Lira
  class Brain
    MAX_ROUNDS = 4

    def initialize(toolkit, adapter: nil)
      @toolkit = toolkit
      @adapter = adapter || self.class.adapter
    end

    def reply(text, history: [])
      return if @adapter.blank?

      @adapter.prepare(
        system: Lira::Scope.system_prompt(professor: @toolkit.professor),
        history: Array(history),
        user: text,
        tools: @toolkit.definitions
      )

      MAX_ROUNDS.times do
        turn = @adapter.complete
        return if turn.blank?

        if turn[:kind].to_s == "text"
          content = turn[:content].to_s.strip
          return content if content.present?

          return
        end

        Array(turn[:calls]).each do |call|
          result = @toolkit.call(call[:name], call[:arguments])
          @adapter.add_tool_result(
            id: call[:id],
            name: call[:name],
            result: result
          )
        end
      end

      nil
    rescue StandardError => error
      Rails.logger.warn("[Lira] cérebro: #{error.class} #{error.message}")
      nil
    end

    def self.adapter
      case Lira.brain_provider
      when :openai then Lira::Brains::OpenAi.new
      when :gemini then Lira::Brains::Gemini.new
      end
    end
  end
end
