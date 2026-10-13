class AutomationNotice < ApplicationRecord
  belongs_to :professor

  validates :kind, :title, :body, :fingerprint, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :newest, -> { order(created_at: :desc) }

  def unread?
    read_at.nil?
  end

  def mark_read!
    update!(read_at: Time.current) if unread?
  end
end
