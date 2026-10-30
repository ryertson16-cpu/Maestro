class Course < ApplicationRecord
  KNOWLEDGE_AREAS = {
    "linguagens_e_codigos" => "Linguagens e Códigos",
    "ciencias_humanas" => "Ciências Humanas",
    "ciencias_da_natureza" => "Ciências da Natureza",
    "matematica" => "Matemática",
    "base_tecnica" => "Base Técnica"
  }.freeze

  KNOWLEDGE_AREA_COLORS = {
    "linguagens_e_codigos" => "purple",
    "ciencias_humanas" => "blue",
    "ciencias_da_natureza" => "green",
    "matematica" => "orange",
    "base_tecnica" => "red"
  }.freeze

  belongs_to :professor

  has_many :classrooms, dependent: :restrict_with_error

  has_many :course_disciplines, dependent: :restrict_with_error

  has_many :school_courses,
          through: :course_disciplines

  has_many :lessons,
           dependent: :restrict_with_error

  has_many :lesson_plan_templates, dependent: :nullify
  has_many :timetable_entries, dependent: :destroy

  validates :name, presence: true

  validates :knowledge_area,
            presence: true,
            inclusion: {
              in: KNOWLEDGE_AREAS.keys
            }

  scope :active, -> { where(active: true) }

  def knowledge_area_label
    KNOWLEDGE_AREAS.fetch(knowledge_area, knowledge_area)
  end

  def knowledge_area_color
    KNOWLEDGE_AREA_COLORS.fetch(knowledge_area, "purple")
  end

  def self.knowledge_area_names
    KNOWLEDGE_AREAS
  end

  def self.technical_base_available_for?(professor)
    professor.grade_levels.where(active: true).any? do |level|
      technical_level_name?(level.name)
    end
  end

  def self.technical_level_name?(name)
    normalized = name.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
    normalized.match?(/\btecnic[oa]s?\b/)
  end

  def self.available_knowledge_areas_for(professor)
    return knowledge_area_names if technical_base_available_for?(professor)

    knowledge_area_names.except("base_tecnica")
  end
end
