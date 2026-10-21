module Courses
  class Catalog
    Entry = Data.define(:knowledge_area, :name)

    DISCIPLINES = [
      ["linguagens_e_codigos", "Língua Portuguesa"],
      ["linguagens_e_codigos", "Literatura"],
      ["linguagens_e_codigos", "Redação"],
      ["linguagens_e_codigos", "Arte"],
      ["linguagens_e_codigos", "Educação Física"],
      ["linguagens_e_codigos", "Língua Inglesa"],
      ["linguagens_e_codigos", "Língua Espanhola"],
      ["linguagens_e_codigos", "Libras"],
      ["linguagens_e_codigos", "Estudo Orientado"],
      ["matematica", "Matemática"],
      ["ciencias_da_natureza", "Biologia"],
      ["ciencias_da_natureza", "Física"],
      ["ciencias_da_natureza", "Química"],
      ["ciencias_humanas", "História"],
      ["ciencias_humanas", "Geografia"],
      ["ciencias_humanas", "Filosofia"],
      ["ciencias_humanas", "Sociologia"],
      ["ciencias_humanas", "Projeto de Vida"],
      ["base_tecnica", "Informática"],
      ["base_tecnica", "Programação"],
      ["base_tecnica", "Redes de Computadores"],
      ["base_tecnica", "Empreendedorismo"],
      ["base_tecnica", "Administração"],
      ["base_tecnica", "Contabilidade"],
      ["base_tecnica", "Desenho Técnico"],
      ["base_tecnica", "Segurança do Trabalho"],
      ["base_tecnica", "Edificações"],
      ["base_tecnica", "Eletrotécnica"],
      ["base_tecnica", "Mecânica"],
      ["base_tecnica", "Agropecuária"],
      ["base_tecnica", "Enfermagem"],
      ["base_tecnica", "Nutrição"],
      ["base_tecnica", "Turismo"],
      ["base_tecnica", "Projeto Integrador"],
      ["base_tecnica", "Estágio Supervisionado"]
    ].map { |area, name| Entry.new(area, name) }.freeze

    def self.entries(include_technical_base: true)
      return DISCIPLINES if include_technical_base

      DISCIPLINES.reject { |entry| entry.knowledge_area == "base_tecnica" }
    end

    def self.grouped(include_technical_base: true)
      entries(include_technical_base: include_technical_base).group_by(&:knowledge_area)
    end

    def self.key_for(entry)
      "#{entry.knowledge_area}::#{entry.name}"
    end

    def self.find_by_key(key)
      area, name = key.to_s.split("::", 2)
      return if area.blank? || name.blank?

      DISCIPLINES.find do |entry|
        entry.knowledge_area == area && entry.name == name
      end
    end
  end
end
