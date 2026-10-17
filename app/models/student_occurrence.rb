class StudentOccurrence < ApplicationRecord
  KINDS = {
    "exit" => "Saída",
    "health" => "Saúde",
    "indiscipline" => "Indisciplina",
    "other" => "Outro"
  }.freeze

  belongs_to :professor
  belongs_to :student
  belongs_to :classroom, optional: true

  validates :occurred_on, presence: true
  validates :body, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS.keys }

  def kind_label
    KINDS.fetch(kind.to_s, kind)
  end

  def recado_text
    classroom_name = classroom&.name.presence || "turma"
    [
      "Olá! Registro pedagógico de #{student.name} (#{classroom_name}) em #{I18n.l(occurred_on)}.",
      "",
      "#{kind_label}: #{body.to_s.strip}",
      "",
      "Fico à disposição para alinhar os próximos passos."
    ].join("\n")
  end

  def whatsapp_url
    "https://wa.me/?text=#{ERB::Util.url_encode(recado_text)}"
  end
end
