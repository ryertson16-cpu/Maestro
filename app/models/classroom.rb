class Classroom < ApplicationRecord
  SHIFT_LABELS = {
    "morning" => "Manhã",
    "afternoon" => "Tarde",
    "evening" => "Noite",
    "full_time" => "Integral"
  }.freeze

  def shift_label
    SHIFT_LABELS.fetch(shift.to_s, shift.to_s.humanize)
  end

  belongs_to :professor

  belongs_to :school_course,
             optional: true

  # Mantido para compatibilidade com turmas antigas.
  # Course representa uma disciplina.
  belongs_to :course,
             optional: true

  belongs_to :grade_level

  has_many :enrollments,
           dependent: :restrict_with_error

  has_many :students,
           through: :enrollments

  has_many :attendance_records,
           through: :enrollments

  has_many :lessons,
           dependent: :restrict_with_error

  has_many :timetable_entries, dependent: :destroy
  has_many :council_notes, dependent: :destroy
  has_many :siage_shipments, dependent: :destroy
  has_many :project_classrooms, dependent: :destroy
  has_many :projects, through: :project_classrooms

  has_many :bimester_settings,
           dependent: :destroy

  has_many :recovery_grades,
           dependent: :destroy

  validates :name,
            presence: true

  validates :school_year,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 2000,
              less_than_or_equal_to: 2100
            }

  validates :shift,
            inclusion: {
              in: %w[morning afternoon evening full_time],
              allow_blank: true
            }

  validate :school_course_belongs_to_professor
  validate :course_belongs_to_professor

  def bimester_setting_for(number)
    bimester_settings.find_or_initialize_by(bimester: number)
  end

  def activities_for_bimester(number)
    lessons
      .joins(:activity)
      .where(activities: { bimester: number })
      .includes(activity: :activity_submissions)
      .order("lessons.lesson_date ASC")
  end

  private

  def school_course_belongs_to_professor
    return if school_course.blank?
    return if school_course.professor_id == professor_id

    errors.add(
      :school_course,
      "não pertence ao professor atual"
    )
  end

  def course_belongs_to_professor
    return if course.blank?
    return if course.professor_id == professor_id

    errors.add(
      :course,
      "não pertence ao professor atual"
    )
  end
end
