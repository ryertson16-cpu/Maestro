class ProjectClassroom < ApplicationRecord
  belongs_to :project
  belongs_to :classroom

  validates :classroom_id, uniqueness: { scope: :project_id }
end
