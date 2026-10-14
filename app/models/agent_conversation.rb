class AgentConversation < ApplicationRecord
  CHANNELS = %w[web whatsapp].freeze

  belongs_to :professor
  has_many :agent_messages, dependent: :destroy

  validates :channel, presence: true, inclusion: { in: CHANNELS }
  validates :external_id, presence: true
  validates :external_id, uniqueness: { scope: %i[professor_id channel] }

  def recent_messages(limit = 16)
    agent_messages.order(:created_at).last(limit)
  end
end
