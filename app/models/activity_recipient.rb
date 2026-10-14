class ActivityRecipient < ApplicationRecord
  belongs_to :activity
  belongs_to :student

  validates :student_id,
            uniqueness: {
              scope: :activity_id,
              message: "já é destinatário desta atividade"
            }
end
