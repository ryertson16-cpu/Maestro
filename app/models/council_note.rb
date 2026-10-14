class CouncilNote < ApplicationRecord
  belongs_to :professor
  belongs_to :classroom
  belongs_to :student

  validates :bimester, presence: true, inclusion: { in: 1..4 }
  validates :body, presence: true
  validates :student_id, uniqueness: { scope: %i[classroom_id bimester] }
end
