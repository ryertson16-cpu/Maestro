module Lira
  module Lookup
    module_function

    STOPWORDS = %w[
      a as o os um uma uns umas de do da dos das em no na nos nas
      para por com sem sobre aluno aluna alunos alunas turma turmas
      professor professora informacao informacoes dados trazer traga
      traz me meu minha meu pedi pedir peço peco quero ver veja fale
      fala sobre chamado chamada chamado chamado lira maestro hoje
      agora desse desta desse dessa esse essa esse esta neste nesta
      frequencia falta faltas nota notas media bimestre aula aulas
      diario monitoramento projeto projetos
    ].freeze

    def classrooms_from(text, classrooms)
      return [] if text.blank?

      exact = classrooms.select { |classroom| Lessons::NameMatcher.classroom_in_text?(text, classroom.name) }
      return exact if exact.any?

      tokens = Lessons::NameMatcher.normalize(text).split
      return [] if tokens.size > 8

      mentioned = Lessons::NameMatcher.serie_and_letters(text).first
      classrooms.select do |classroom|
        next false if mentioned.present? && Lessons::NameMatcher.serie_and_letter(classroom.name) != mentioned

        Lessons::NameMatcher.similar?(text, classroom.name)
      end
    end

    def students_from(text, students)
      scored = students.filter_map do |student|
        score = student_score(text, student.name)
        next if score <= 0

        [score, student]
      end

      scored.sort_by { |score, student| [-score, student.name] }
            .then { |rows| keep_top_scores(rows) }
    end

    def student_score(text, name)
      hay = Lessons::NameMatcher.normalize(text)
      needle = Lessons::NameMatcher.normalize(name)
      return 0 if hay.blank? || needle.blank?

      return 100 if hay == needle
      return 90 if hay.include?(needle) && needle.split.size >= 2

      name_tokens = significant_tokens(needle)
      return 0 if name_tokens.empty?

      hay_tokens = hay.split
      return 80 if name_tokens.size >= 2 && (name_tokens - hay_tokens).empty?

      first = name_tokens.first
      return 0 unless hay.match?(/\b#{Regexp.escape(first)}\b/)

      last = name_tokens.last
      if name_tokens.size >= 2 && last != first && hay.match?(/\b#{Regexp.escape(last)}\b/)
        return 70
      end

      40
    end

    def significant_tokens(name)
      Lessons::NameMatcher.normalize(name).split.reject do |token|
        token.length < 3 || STOPWORDS.include?(token)
      end
    end

    def keep_top_scores(rows)
      return [] if rows.empty?

      best = rows.first[0]
      rows.select { |score, _| score == best }.map(&:last)
    end
  end
end
