module Lira
  class ChatsController < ApplicationController
    before_action :authenticate_professor!

    def show
      @conversation = current_conversation
      @messages = @conversation.agent_messages.order(:created_at)
      @wake_text = Lira::DailyBriefing.new(professor: current_professor).wake_text
    end

    def create
      @conversation = current_conversation
      @reply = ::Lira::Responder.new(
        professor: current_professor,
        conversation: @conversation
      ).reply(params[:body])

      @messages = @conversation.agent_messages.order(:created_at)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to lira_path }
      end
    end

    private

    def current_conversation
      current_professor.lira_conversation_for(channel: "web", external_id: "web")
    end
  end
end
