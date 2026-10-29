class DeskMessage < ApplicationRecord
  DIRECTIONS = %w[inbound outbound].freeze
  INTENTS = %w[sales support billing other].freeze

  belongs_to :professor, optional: true

  validates :whatsapp_number, presence: true
  validates :body, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :intent, inclusion: { in: INTENTS }, allow_blank: true
  validates :external_id, uniqueness: { allow_nil: true }

  before_validation :normalize_fields

  scope :newest, -> { order(created_at: :desc) }

  def direction_label
    direction == "outbound" ? "Enviada" : "Recebida"
  end

  private

  def normalize_fields
    self.whatsapp_number = Lira::Phone.digits(whatsapp_number).presence
    self.name = name.to_s.strip.presence
    self.email = email.to_s.strip.downcase.presence
    self.body = body.to_s.strip
    self.intent = intent.to_s.strip.downcase.presence
    self.external_id = external_id.to_s.strip.presence
    self.direction = direction.to_s.strip.downcase.presence || "inbound"
  end
end
