class GradeLevel < ApplicationRecord
  belongs_to :professor

  has_many :classrooms, dependent: :restrict_with_error
  has_many :bimester_actions, dependent: :destroy
  has_many :series_bimester_settings, dependent: :destroy

  validates :name, presence: true
end
