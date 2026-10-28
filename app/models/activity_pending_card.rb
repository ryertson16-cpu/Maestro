class ActivityPendingCard < ApplicationRecord
  belongs_to :activity
  belongs_to :student, optional: true
  has_one_attached :card

  validates :filename, presence: true
  validates :filled_count, numericality: { greater_than_or_equal_to: 0 }
  validate :card_must_be_scan, if: -> { card.attached? }

  def name_hint
    suggested_name.presence
  end

  private

  def card_must_be_scan
    type = card.content_type.to_s
    name = card.filename.to_s.downcase
    return if type.match?(%r{\A(application/pdf|image/(png|jpe?g|webp|gif))\z}i)
    return if name.match?(/\.(pdf|png|jpe?g|webp|gif)\z/)

    errors.add(:card, "envie uma foto ou um PDF do cartão")
  end
end
