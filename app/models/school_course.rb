class SchoolCourse < ApplicationRecord
  belongs_to :professor

  has_many :course_disciplines,
           -> { order(:position, :id) },
           dependent: :destroy

  has_many :courses,
           through: :course_disciplines

  validates :name, presence: true

  scope :active, -> { where(active: true) }
end
