class ActivityQuestion < ApplicationRecord
  belongs_to :activity
  belongs_to :question, optional: true

  validates :prompt, presence: true
  validates :kind, presence: true, inclusion: { in: Question::KINDS.keys }
  validates :position, numericality: { greater_than: 0 }
  validates :points, numericality: { greater_than: 0 }
  validates :correct_letter,
            inclusion: { in: Question::LETTERS },
            if: :objective?

  def objective?
    kind.to_s == "objective"
  end

  def discursive?
    kind.to_s == "discursive"
  end

  def choice_pairs
    Array(choices).map do |item|
      if item.is_a?(Hash)
        [item["letter"].presence || item[:letter], item["text"].presence || item[:text]]
      else
        [nil, item]
      end
    end.select { |_letter, text| text.to_s.strip.present? }
  end

  def self.snapshot_from(question, position:)
    new(
      question: question,
      position: position,
      prompt: question.prompt,
      kind: question.kind,
      choices: question.choices,
      correct_letter: question.correct_letter,
      points: question.points,
      bncc_skill: question.bncc_skill
    )
  end
end
