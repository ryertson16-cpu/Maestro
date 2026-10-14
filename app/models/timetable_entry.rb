class TimetableEntry < ApplicationRecord
  WEEKDAY_LABELS = {
    1 => "Segunda",
    2 => "Terça",
    3 => "Quarta",
    4 => "Quinta",
    5 => "Sexta",
    6 => "Sábado"
  }.freeze

  belongs_to :professor
  belongs_to :classroom
  belongs_to :course, optional: true

  validates :weekday, presence: true, inclusion: { in: 1..6 }
  validates :period, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :period, uniqueness: { scope: %i[professor_id classroom_id weekday] }

  def weekday_label
    WEEKDAY_LABELS.fetch(weekday, weekday.to_s)
  end

  def time_slot_label
    time_slot.presence || "#{period}º tempo"
  end
end
