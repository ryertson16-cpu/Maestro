class SeriesBimesterSetting < ApplicationRecord
  belongs_to :professor
  belongs_to :grade_level

  validates :bimester, inclusion: { in: 1..4 }
  validates :target_average,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10 },
            allow_nil: true
  validates :grade_level_id, uniqueness: { scope: %i[professor_id bimester] }
end
