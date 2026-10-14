module Projects
  module StageCatalog
    module_function

    def for(kind)
      case kind.to_s
      when "professor_nota_10"
        [
          { title: "Diagnóstico da prática", description: "Registre o ponto de partida da sua atuação em sala." },
          { title: "Plano de ação", description: "Defina metas, prazos e o que será feito." },
          { title: "Execução", description: "Acompanhe as ações previstas no plano." },
          { title: "Evidências", description: "Reúna fotos, planos, avaliações e registros." },
          { title: "Relatório", description: "Feche o percurso para a regional ou a escola." }
        ]
      when "school_nota_10"
        [
          { title: "Diagnóstico institucional", description: "Mapeie a escola, a comunidade e as prioridades." },
          { title: "Plano de ação da escola", description: "Combine metas com a equipe e os parceiros." },
          { title: "Execução com a comunidade", description: "Registre as ações realizadas na escola." },
          { title: "Evidências", description: "Anexe atas, fotos, listas e materiais." },
          { title: "Relatório para a regional", description: "Organize o portfólio para a GRE." }
        ]
      when "classroom"
        [
          { title: "Apresentação e combinados", description: "Apresente o projeto à turma e alinhe o percurso." },
          { title: "Desenvolvimento", description: "Realize as atividades previstas com os alunos." },
          { title: "Culminância", description: "Registre a apresentação, a mostra ou o produto final." },
          { title: "Avaliação e registro", description: "Avalie o processo e arquive as evidências." }
        ]
      else
        [
          { title: "Planejamento", description: "Descreva o que será feito nesta etapa." },
          { title: "Execução", description: "Registre o andamento e as evidências." }
        ]
      end
    end
  end
end
