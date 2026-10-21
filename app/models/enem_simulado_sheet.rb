class EnemSimuladoSheet < ApplicationRecord
  belongs_to :enem_simulado
  belongs_to :student
  belongs_to :classroom, optional: true

  has_one_attached :card_pdf

  before_validation :assign_classroom

  validates :student_id, uniqueness: { scope: :enem_simulado_id, message: "já tem cartão neste simulado" }
  validate :student_in_caderno
  validate :card_pdf_must_be_pdf, if: -> { card_pdf.attached? }

  def normalized_answers
    Array(answers).first(Enem::ScoreScale::QUESTION_COUNT).map { |letter|
      value = letter.to_s.upcase
      Question::LETTERS.include?(value) ? value : nil
    }.then { |list| list.fill(nil, list.length...Enem::ScoreScale::QUESTION_COUNT) }
  end

  def recompute!
    breakdown = enem_simulado.hits_breakdown(normalized_answers)
    self.cn_hits = breakdown[:cn_hits]
    self.mt_hits = breakdown[:mt_hits]
    self.hits = breakdown[:hits]
    self.score = Enem::ScoreScale.note_for(hits)
  end

  def ready?
    normalized_answers.any? { |letter| Question::LETTERS.include?(letter) }
  end

  def letter_at(position)
    normalized_answers[position.to_i - 1]
  end

  def classroom_label
    classroom&.name.presence || "Sem turma"
  end

  private

  def assign_classroom
    return if classroom.present? || student.blank?

    self.classroom = Enem::ClassroomResolver.new(
      student: student,
      preferred: enem_simulado&.classroom
    ).classroom
  end

  def student_in_caderno
    return if enem_simulado.blank? || student.blank?
    return if student.professor_id == enem_simulado.professor_id

    errors.add(:student, "não pertence a este caderno")
  end

  def card_pdf_must_be_pdf
    return if card_pdf.content_type.to_s.match?(%r{\Aapplication/pdf\z}i)
    return if card_pdf.filename.to_s.downcase.end_with?(".pdf")

    errors.add(:card_pdf, "envie um PDF")
  end
end
