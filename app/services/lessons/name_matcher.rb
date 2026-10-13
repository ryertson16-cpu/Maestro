module Lessons
  module NameMatcher
    module_function

    def normalize(value)
      value.to_s
           .unicode_normalize(:nfd)
           .gsub(/\p{M}/, "")
           .downcase
           .gsub(/[^a-z0-9]+/, " ")
           .squeeze(" ")
           .strip
    end

    def similar?(left, right)
      a = normalize(left)
      b = normalize(right)
      return false if a.blank? || b.blank?
      return true if a == b
      return true if a.include?(b) || b.include?(a)

      tokens_a = a.split
      tokens_b = b.split
      return true if tokens_a.first == tokens_b.first && tokens_a.first.to_s.length >= 4

      (tokens_a & tokens_b).size >= 1 && [tokens_a, tokens_b].min_by(&:size).size == 1
    end

    def discipline_match?(left, right)
      return true if similar?(left, right)

      a = core_discipline(left)
      b = core_discipline(right)
      return false if a.blank? || b.blank?
      return true if a == b
      return true if a.length >= 4 && b.length >= 4 && (a.start_with?(b) || b.start_with?(a))

      false
    end

    def professor_in_text?(text, professor_name)
      first = normalize(professor_name).split.first
      return false if first.blank?

      normalize(text).split.include?(first) || normalize(text).include?(first)
    end

    def classroom_in_text?(text, classroom_name)
      hay = normalize(text)
      needle = normalize(classroom_name)
      return false if hay.blank? || needle.blank?
      return true if hay == needle

      wanted = serie_and_letter(classroom_name)
      mentioned = serie_and_letters(text)
      return mentioned.include?(wanted) if wanted.present? && mentioned.any?
      return true if needle.length >= 4 && hay.include?(needle)
      return false if wanted.blank?

      serie, letter = wanted
      hay.match?(/\b#{Regexp.escape(serie)}\s*(a|o)?\s*(serie)?\s*#{Regexp.escape(letter)}\b/)
    end

    def serie_and_letter(name)
      serie_and_letters(name).first
    end

    def serie_and_letters(name)
      normalize(name).scan(/\b(\d+)\s*(a|o)?\s*(serie)?\s*([a-z])\b/).map do |match|
        [match[0], match[3]]
      end
    end

    def weekday_in_text(text, filename: nil)
      from_file = weekday_from_filename(filename)
      return from_file if from_file

      n = normalize(text)
      days = %w[segunda terca quarta quinta sexta sabado domingo]
      counts = days.map { |day| [day, n.scan(/\b#{day}\b/).size] }
      best = counts.max_by { |(_day, count)| count }
      best && best[1].positive? ? best[0] : nil
    end

    def weekday_from_filename(filename)
      n = normalize(filename)
      %w[segunda terca quarta quinta sexta sabado domingo].find { |day| n.include?(day) }
    end

    def core_discipline(value)
      aliases = {
        "georgrafia" => "geografia",
        "lingua portuguesa" => "portugues",
        "producao textual" => "portugues",
        "educacao f" => "educacao fisica",
        "imunulogia" => "imunologia",
        "recomposicao mat" => "matematica"
      }
      n = normalize(value)
      n = aliases.fetch(n, n)
      n.gsub(/\b(disciplina|componente|curricular|aula de|aula)\b/, "")
       .squeeze(" ")
       .strip
    end
  end
end
