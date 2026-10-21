class School < ApplicationRecord
  REGIONALS = [
    "1ª GRE — João Pessoa",
    "2ª GRE — Guarabira",
    "3ª GRE — Campina Grande",
    "4ª GRE — Cuité",
    "5ª GRE — Monteiro",
    "6ª GRE — Patos",
    "7ª GRE — Itaporanga",
    "8ª GRE — Catolé do Rocha",
    "9ª GRE — Pombal",
    "10ª GRE — Sousa",
    "11ª GRE — Princesa Isabel",
    "12ª GRE — Itabaiana",
    "13ª GRE — Piancó",
    "14ª GRE — Mamanguape",
    "Outra"
  ].freeze

  belongs_to :professor
  has_one_attached :crest

  validates :name, presence: true
  validates :regional, inclusion: { in: REGIONALS, allow_blank: true }
  validates :regional_other, presence: true, if: :other_regional?

  def other_regional?
    regional == "Outra"
  end

  def regional_label
    return if regional.blank?
    return regional_other.presence || "Outra regional" if other_regional?

    regional
  end
end
