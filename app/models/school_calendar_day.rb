class SchoolCalendarDay < ApplicationRecord
  KINDS = %w[holiday saturday_school no_class planning milestone].freeze
  KIND_LABELS = {
    "holiday" => "Feriado",
    "saturday_school" => "Sábado letivo",
    "no_class" => "Recesso",
    "planning" => "Planejamento",
    "milestone" => "Marco letivo"
  }.freeze

  belongs_to :professor

  validates :day, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :day, uniqueness: { scope: :professor_id }

  def kind_label
    KIND_LABELS.fetch(kind, kind)
  end

  def blocks_lessons?
    kind.in?(%w[holiday no_class planning])
  end
end
