class EnemSimulado < ApplicationRecord
  belongs_to :professor
  belongs_to :classroom
  belongs_to :activity, optional: true

  has_many :sheets, class_name: "EnemSimuladoSheet", dependent: :destroy
  has_many :pending_cards, class_name: "EnemPendingCard", dependent: :destroy
  has_one_attached :official_pdf

  validates :title, presence: true
  validates :applied_on, presence: true
  validates :bimester, presence: true, inclusion: { in: Activity::BIMESTERS.keys }
  validates :question_count, numericality: { equal_to: Enem::ScoreScale::QUESTION_COUNT }
  validate :classroom_belongs_to_professor
  validate :official_pdf_must_be_pdf, if: -> { official_pdf.attached? }

  def students
    classroom.students.order(:name)
  end

  def students_in_caderno
    professor.students.joins(:enrollments).distinct.includes(enrollments: :classroom).order(:name)
  end

  def normalized_key
    Array(official_key).first(Enem::ScoreScale::QUESTION_COUNT).map { |letter|
      value = letter.to_s.upcase
      Question::LETTERS.include?(value) ? value : nil
    }.then { |list| list.fill(nil, list.length...Enem::ScoreScale::QUESTION_COUNT) }
  end

  def key_complete?
    normalized_key.all? { |letter| Question::LETTERS.include?(letter) }
  end

  def hits_breakdown(answers)
    key = normalized_key
    letters = Array(answers)
    cn = Enem::ScoreScale::CN_RANGE.count { |index| hit?(letters[index], key[index]) }
    mt = Enem::ScoreScale::MT_RANGE.count { |index| hit?(letters[index], key[index]) }
    { cn_hits: cn, mt_hits: mt, hits: cn + mt }
  end

  def hits_for(answers)
    hits_breakdown(answers)[:hits]
  end

  def area_for(position)
    position.to_i <= Enem::ScoreScale::CN_COUNT ? "CN" : "MT"
  end

  private

  def hit?(letter, expected)
    value = letter.to_s.upcase
    Question::LETTERS.include?(value) && value == expected.to_s.upcase
  end

  def classroom_belongs_to_professor
    return if classroom.blank? || professor.blank?
    return if classroom.professor_id == professor_id

    errors.add(:classroom, "não pertence a este caderno")
  end

  def official_pdf_must_be_pdf
    return if official_pdf.content_type.to_s.match?(%r{\Aapplication/pdf\z}i)
    return if official_pdf.filename.to_s.downcase.end_with?(".pdf")

    errors.add(:official_pdf, "envie um PDF")
  end
end
