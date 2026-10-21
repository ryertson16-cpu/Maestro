class EnemPendingCard < ApplicationRecord
  belongs_to :enem_simulado
  has_one_attached :card_pdf

  validates :filename, presence: true

  def name_hint
    suggested_name.presence
  end
  validate :card_pdf_must_be_pdf, if: -> { card_pdf.attached? }

  private

  def card_pdf_must_be_pdf
    return if card_pdf.content_type.to_s.match?(%r{\Aapplication/pdf\z}i)
    return if card_pdf.filename.to_s.downcase.end_with?(".pdf")

    errors.add(:card_pdf, "envie um PDF")
  end
end
