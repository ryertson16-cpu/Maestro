class Question < ApplicationRecord
  KINDS = {
    "objective" => "Objetiva",
    "discursive" => "Discursiva"
  }.freeze

  LETTERS = %w[A B C D E].freeze

  belongs_to :professor
  belongs_to :course, optional: true
  has_many :activity_questions, dependent: :nullify

  validates :prompt, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS.keys }
  validates :points, numericality: { greater_than: 0 }
  validates :correct_letter,
            inclusion: { in: LETTERS },
            if: :objective?
  validate :objective_choices_present

  scope :objective, -> { where(kind: "objective") }
  scope :discursive, -> { where(kind: "discursive") }
  scope :search, ->(query) {
    next all if query.blank?

    needle = "%#{query.to_s.strip}%"
    where("prompt LIKE ? OR tag LIKE ? OR bncc_skill LIKE ?", needle, needle, needle)
  }

  def objective?
    kind.to_s == "objective"
  end

  def discursive?
    kind.to_s == "discursive"
  end

  def kind_label
    KINDS.fetch(kind.to_s, kind)
  end

  def choice_pairs
    Array(choices).map do |item|
      if item.is_a?(Hash)
        [item["letter"].presence || item[:letter], item["text"].presence || item[:text]]
      else
        [nil, item]
      end
    end
  end

  def self.normalize_choices(raw_letters, raw_texts)
    LETTERS.filter_map.with_index do |letter, index|
      text = Array(raw_texts)[index].to_s.strip
      next if text.blank?

      { "letter" => letter, "text" => text }
    end
  end

  private

  def objective_choices_present
    return unless objective?

    pairs = choice_pairs.select { |_letter, text| text.to_s.strip.present? }
    if pairs.size < 2
      errors.add(:choices, "informe pelo menos duas alternativas")
      return
    end

    letters = pairs.map(&:first)
    return if correct_letter.blank? || letters.include?(correct_letter)

    errors.add(:correct_letter, "precisa ser uma das alternativas preenchidas")
  end
end
