class ActivityExamAssignment < ApplicationRecord
  belongs_to :activity
  belongs_to :student

  validates :slot, numericality: { greater_than: 0 }
  validates :student_id, uniqueness: { scope: :activity_id }
end
