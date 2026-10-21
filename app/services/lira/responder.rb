module Lira
  class Responder
    def initialize(professor:, conversation:)
      @professor = professor
      @conversation = conversation
      @toolkit = Toolkit.new(professor)
    end

    def reply(text, metadata: {})
      body = text.to_s.strip
      if body.blank?
        return conversation_reply(
          Lira::Scope.with_opening("", professor: @professor, topic: :blank)
        )
      end

      @conversation.agent_messages.create!(
        role: "user",
        body: body,
        metadata: metadata
      )

      answer = generate(body)
      answer = answer.to_s.strip.presence || "Não consegui montar a resposta agora. Tente de outro jeito, com o nome da turma ou do aluno."
      answer = Lira::Scope.with_opening(answer, professor: @professor, topic: Lira::Scope.topic_for(body))
      answer = answer.truncate(3900, omission: "…")

      @conversation.agent_messages.create!(
        role: "assistant",
        body: answer
      )

      answer
    end

    private

    def generate(text)
      command = Maestro::CommandInterpreter.new(@professor).reply(text)
      return command if command.present?

      if Lira.llm_enabled?
        llm = LlmClient.new(@toolkit).reply(text, history: history_for_llm)
        return llm if llm.present?
      end

      LocalInterpreter.new(@toolkit).reply(text)
    end

    def history_for_llm
      messages = @conversation.recent_messages(10)
      messages.pop if messages.last&.user?

      messages.filter_map do |message|
        next if message.body.blank?

        { role: message.role, content: message.body }
      end
    end

    def conversation_reply(text)
      @conversation.agent_messages.create!(role: "assistant", body: text)
      text
    end
  end
end
