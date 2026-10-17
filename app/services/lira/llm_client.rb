module Lira
  class LlmClient
    def initialize(toolkit)
      @toolkit = toolkit
    end

    def reply(text, history: [])
      Brain.new(@toolkit).reply(text, history: history)
    end
  end
end
