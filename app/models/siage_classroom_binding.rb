class SiageClassroomBinding < ApplicationRecord
  belongs_to :professor
  belongs_to :classroom
  belongs_to :course, optional: true

  validates :turma_name, presence: true
end
