class AgentMessage < ApplicationRecord
  ROLES = %w[user assistant].freeze

  belongs_to :agent_conversation

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :body, presence: true

  def user?
    role == "user"
  end

  def assistant?
    role == "assistant"
  end
end
