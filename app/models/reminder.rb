class Reminder < ApplicationRecord
  belongs_to :professor
  belongs_to :classroom, optional: true
  belongs_to :automation_notice, optional: true

  validates :title, presence: true, length: { maximum: 160 }
  validates :remind_at, presence: true

  scope :kept, -> { where(undone_at: nil) }
  scope :upcoming, -> {
    kept.where(fired_at: nil).where("remind_at > ?", Time.current).order(:remind_at)
  }
  scope :due, -> {
    kept.where(fired_at: nil).where("remind_at <= ?", Time.current).order(:remind_at)
  }

  def undone?
    undone_at.present?
  end

  def fired?
    fired_at.present?
  end

  def undo!
    update!(undone_at: Time.current) unless undone?
  end
end
