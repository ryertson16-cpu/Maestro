class BimesterAction < ApplicationRecord
  belongs_to :professor
  belongs_to :grade_level

  validates :title, presence: true, length: { maximum: 160 }
  validates :audience, length: { maximum: 160 }, allow_blank: true
  validates :bimester, inclusion: { in: 1..4 }
  validates :position, numericality: { only_integer: true, greater_than: 0 }

  scope :in_series, ->(grade_level, bimester) {
    where(grade_level: grade_level, bimester: bimester).order(:position, :id)
  }

  def self.next_position_for(professor:, grade_level:, bimester:)
    where(professor: professor, grade_level: grade_level, bimester: bimester).maximum(:position).to_i + 1
  end
end
