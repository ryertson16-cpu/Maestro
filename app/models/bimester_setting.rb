class BimesterSetting < ApplicationRecord
  BIMESTERS = {
    1 => "1º Bimestre",
    2 => "2º Bimestre",
    3 => "3º Bimestre",
    4 => "4º Bimestre"
  }.freeze

  belongs_to :classroom

  validates :bimester,
            inclusion: {
              in: BIMESTERS.keys
            }

  validates :minimum_score,
            numericality: {
              greater_than_or_equal_to: 0,
              less_than_or_equal_to: 10
            }

  validates :classroom_id,
            uniqueness: {
              scope: :bimester
            }

  def bimester_label
    BIMESTERS.fetch(bimester)
  end

  def closed?
    closed_at.present?
  end

  def close!
    update!(closed_at: Time.current)
  end

  def reopen!
    update!(closed_at: nil)
  end
end