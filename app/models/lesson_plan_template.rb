class LessonPlanTemplate < ApplicationRecord
  belongs_to :professor
  belongs_to :course, optional: true
  has_many :lessons, dependent: :nullify

  validates :title, presence: true

  def apply_to(lesson)
    lesson.theme = theme if theme.present?
    lesson.objective = objective if objective.present?
    lesson.content = content if content.present?
    lesson.methodology = methodology if methodology.present?
    lesson.course_id = course_id if course_id.present? && lesson.course_id.blank?
    lesson.lesson_plan_template = self
  end
end
