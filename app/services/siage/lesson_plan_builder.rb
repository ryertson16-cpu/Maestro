module Siage
  class LessonPlanBuilder
    def self.for(lesson)
      new(lesson).to_h
    end

    def initialize(lesson)
      @lesson = lesson
    end

    def to_h
      {
        teaching_plan: teaching_plan,
        thematic_unit: thematic_unit,
        knowledge_objects: knowledge_objects,
        competencies: competencies,
        skills: skills,
        methodology: methodology_text,
        observations: observations
      }
    end

    private

    attr_reader :lesson

    def teaching_plan
      course = lesson.course&.name.to_s.strip
      return "#{course} — plano de ensino vigente" if course.present?

      "Plano de ensino da componente curricular"
    end

    def thematic_unit
      "Unidade temática: #{theme}"
    end

    def knowledge_objects
      text = clean(lesson.content)
      return text if text.present?

      "Objetos de conhecimento relacionados a #{theme}, com ênfase na aplicação prática dos conteúdos da aula."
    end

    def competencies
      text = clean(lesson.objective)
      return text if text.present?

      "Compreender e aplicar #{theme}, articulando conceitos, procedimentos e atitudes no contexto da formação técnica."
    end

    def skills
      "Identificar, analisar e registrar #{theme}; utilizar os procedimentos trabalhados na aula; comunicar os resultados com clareza."
    end

    def methodology_text
      text = clean(lesson.methodology)
      return text if text.present?

      if lesson.siage_class_mode.to_s.match?(/avalia/i)
        "Avaliação alinhada ao tema #{theme}, com orientação inicial, realização da atividade e devolutiva dos critérios de correção."
      else
        "Exposição dialogada sobre #{theme}, seguida de atividade prática, acompanhamento do professor e síntese coletiva."
      end
    end

    def observations
      date = lesson.lesson_date&.strftime("%d/%m/%Y")
      "Registro da aula de #{date} sobre #{theme}. Campos pedagógicos preenchidos de forma consistente a partir do tema, objetivo, conteúdo e metodologia lançados no Maestro."
    end

    def theme
      clean(lesson.theme).presence || "os conteúdos previstos para a aula"
    end

    def clean(value)
      value.to_s.gsub(/\s+/, " ").strip.presence
    end
  end
end
