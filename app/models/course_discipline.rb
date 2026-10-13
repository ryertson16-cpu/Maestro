class CourseDiscipline < ApplicationRecord
  belongs_to :school_course
  belongs_to :course

  validates :course_id,
            uniqueness: {
              scope: :school_course_id,
              message: "já está vinculada a este curso"
            }

  validates :position,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0
            }
end
