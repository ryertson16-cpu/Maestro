class SiageRosterImport < ApplicationRecord
  STATUSES = %w[pending_review applied empty failed].freeze

  belongs_to :professor

  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :newest, -> { order(created_at: :desc) }

  def pending_review?
    status == "pending_review"
  end

  def applied?
    status == "applied"
  end
end
