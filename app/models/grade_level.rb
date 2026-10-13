class GradeLevel < ApplicationRecord
  belongs_to :professor

  has_many :classrooms, dependent: :restrict_with_error

  validates :name, presence: true
end
