module Lessons
  class TimetableParser
    COMMON_SUBJECTS = %w[
      filosofia biologia geografia georgrafia matematica sociologia quimica fisica
      historia imunologia imunulogia ingles portugues lingua portuguesa
      educacao fisica histologia patologia genetica bioquimica
      desenvolvimento rural linguagem programacao computacao grafica
      engenharia software educacao digital producao textual
      recomposicao imunulogia fht
    ].freeze

    NAME_CONTINUATIONS = %w[junior jr filho neto a].freeze
    CLASS_HEADER = /\b(\d+)\s*[ªºa]?\s*s[eé]rie\s+([a-z])\b/i.freeze
    PERIOD_HEADER = /\b([1-9]|1[0-9])\s+(\d{2}:\d{2})\s*-\s*(\d{2}:\d{2})\b/i.freeze

    def initialize(text:, professor:, classroom:, courses:, pdf: nil)
      @text = text.to_s
      @professor = professor
      @classroom = classroom
      @courses = Array(courses)
      @pdf = pdf
      @professor_first = NameMatcher.normalize(professor.name).split.first
    end

    def slots
      layout = layout_slots
      if layout.any?
        catalog = layout.select { |slot| catalog_subject?(slot[:subject]) }
        return catalog if catalog.any?

        return layout
      end

      sources = [block_slots, aligned_slots, name_follow_slots]
      catalog_hits = sources.map { |list| list.select { |slot| catalog_subject?(slot[:subject]) } }
                            .find(&:any?)
      return catalog_hits if catalog_hits

      sources.find(&:any?) || []
    end

    private

    def flattened
      @flattened ||= @text.gsub(/[‐–—−]/, "-").gsub(/\s+/, " ").strip
    end

    def layout_slots
      items = pdf_runs
      return [] if items.size < 8

      header_x = classroom_header_x(items)
      name_runs = items.select { |item| professor_matches?(item[:text]) }

      name_runs.filter_map do |name_run|
        next if header_x && (name_run[:x] - header_x).abs > 50

        subject_run = nearest_subject_below(items, name_run)
        next unless subject_run
        next unless subject_known?(subject_run[:text])

        period, start_time, end_time = period_near(items, name_run)

        {
          period: period || 1,
          start_time: start_time,
          end_time: end_time,
          teacher: name_run[:text],
          subject: clean_subject(subject_run[:text])
        }
      end
    rescue StandardError
      []
    end

    def pdf_runs
      return [] unless @pdf

      io = @pdf
      io.rewind if io.respond_to?(:rewind)
      PDF::Reader.new(io).pages.flat_map { |page| runs_for(page) }
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
      []
    end

    def runs_for(page)
      return [] unless page.respond_to?(:runs)

      Array(page.runs).filter_map do |run|
        text = run.text.to_s.gsub(/\s+/, " ").strip
        next if text.blank?

        x, y = run_xy(run)
        next unless x && y

        { text: text, x: x, y: y }
      end
    end

    def run_xy(run)
      origin = run.origin
      if origin.respond_to?(:x)
        [origin.x.to_f, origin.y.to_f]
      elsif origin.respond_to?(:[])
        [origin[0].to_f, origin[1].to_f]
      end
    end

    def classroom_header_x(items)
      serie, letter = NameMatcher.serie_and_letter(@classroom.name)
      return unless serie && letter

      items.each do |item|
        match = item[:text].match(CLASS_HEADER)
        next unless match
        return item[:x] if match[1] == serie && match[2].downcase == letter
      end

      serie_runs = items.select do |item|
        NameMatcher.normalize(item[:text]).match?(/\A#{Regexp.escape(serie)}\s*a?\s*serie\z/)
      end
      serie_runs.each do |serie_run|
        letter_run = items.find do |item|
          NameMatcher.normalize(item[:text]) == letter &&
            (item[:x] - serie_run[:x]).abs <= 48 &&
            (item[:y] - serie_run[:y]).abs <= 22
        end
        return letter_run[:x] if letter_run
      end

      nil
    end

    def nearest_subject_below(items, name_run)
      items
        .select do |item|
          subject_known?(item[:text]) &&
            item[:y] < name_run[:y] - 2 &&
            (name_run[:y] - item[:y]) <= 28 &&
            (item[:x] - name_run[:x]).abs <= 42
        end
        .max_by { |item| item[:y] }
    end

    def period_near(items, name_run)
      nearby = items.select { |item| (item[:y] - name_run[:y]).abs <= 22 }
      joined = nearby.sort_by { |item| item[:x] }.map { |item| item[:text] }.join(" ")
      match = joined.match(PERIOD_HEADER)
      return [match[1].to_i, match[2], match[3]] if match

      number = nearby.find { |item| item[:text].match?(/\A([1-9]|1[0-9])\z/) && item[:x] < 100 }
      times = nearby.filter_map { |item| item[:text][/\d{2}:\d{2}/] }
      return unless number && times.any?

      [number[:text].to_i, times[0], times[1]]
    end

    def classes
      @classes ||= flattened.to_enum(:scan, CLASS_HEADER).map do
        match = Regexp.last_match
        {
          serie: match[1],
          letter: match[2].to_s.upcase,
          label: "#{match[1]}ª SÉRIE #{match[2]}"
        }
      end.uniq { |row| "#{row[:serie]}-#{row[:letter]}" }
    end

    def period_blocks
      @period_blocks ||= begin
        matches = flattened.to_enum(:scan, PERIOD_HEADER).map { Regexp.last_match }
        matches.each_with_index.map do |match, index|
          start_at = match.end(0)
          end_at = matches[index + 1] ? matches[index + 1].begin(0) : next_boundary(start_at)
          {
            period: match[1].to_i,
            start_time: match[2],
            end_time: match[3],
            body: flattened[start_at...end_at].to_s
          }
        end.select { |block| (1..19).cover?(block[:period]) }
      end
    end

    def next_boundary(from)
      rest = flattened[from..]
      return flattened.length unless rest

      offset = rest =~ /\b(?:INTERVALO|ALMO[CÇ]O|PROFESSORES)\b/i
      offset ? from + offset : flattened.length
    end

    def block_slots
      period_blocks.flat_map { |block| unaligned_slots_in(block) }
    end

    def aligned_slots
      period_blocks.flat_map do |block|
        pairs = teacher_subject_pairs(block[:body])
        mapped = zip_classes(pairs)
        next [] if mapped.blank?

        mapped.filter_map do |klass, teacher, subject|
          next unless class_matches?(klass)
          next unless professor_matches?(teacher)
          next unless subject_known?(subject)

          slot_hash(block, teacher, subject)
        end
      end
    end

    def unaligned_slots_in(block)
      teacher_subject_pairs(block[:body]).filter_map do |teacher, subject|
        next unless professor_matches?(teacher)
        next unless subject_known?(subject)

        slot_hash(block, teacher, subject)
      end
    end

    def name_follow_slots
      tokens = flattened.split
      first = @professor_first
      return [] if first.blank?

      hits = []
      tokens.each_with_index do |token, index|
        next unless NameMatcher.similar?(token, first)

        subject = lookahead_subject(tokens, index + 1)
        next unless subject

        period = nearest_period_before(index, tokens)
        hits << {
          period: period || 1,
          start_time: nil,
          end_time: nil,
          teacher: token,
          subject: subject
        }
      end
      hits.uniq { |hit| [hit[:period], NameMatcher.normalize(hit[:subject])] }
    end

    def lookahead_subject(tokens, start)
      i = start
      while i < tokens.length && skip_token?(tokens[i])
        i += 1
      end
      return nil if i >= tokens.length
      return nil if period_start?(tokens, i)

      1.upto(3) do |length|
        chunk = tokens[i, length]&.join(" ")
        break if chunk.blank?
        break if chunk.match?(/\d{2}:\d{2}/)
        return clean_subject(chunk) if subject_known?(chunk)
      end
      nil
    end

    def skip_token?(token)
      token.match?(/\A\d{1,2}\z/) ||
        token.match?(/\A\d{2}:\d{2}\z/) ||
        token == "-" ||
        token.match?(/\Aintervalo\z/i) ||
        token.match?(/\Aalmo/i)
    end

    def period_start?(tokens, index)
      tokens[index].to_s.match?(/\A(?:[1-9]|1[0-9])\z/) &&
        tokens[index + 1].to_s.match?(/\A\d{2}:\d{2}\z/)
    end

    def clean_subject(text)
      text.to_s.gsub(/\d{2}:\d{2}/, "").gsub(/\s*-\s*/, " ").gsub(/\s+/, " ").strip
    end

    def catalog_subject?(text)
      @courses.any? { |course| NameMatcher.discipline_match?(text, course.name) }
    end

    def nearest_period_before(token_index, tokens)
      joined_until = tokens[0...token_index].join(" ")
      match = joined_until.scan(PERIOD_HEADER).last
      match&.first.to_i.then { |num| (1..19).cover?(num) ? num : nil }
    end

    def zip_classes(pairs)
      return [] if pairs.blank? || classes.blank?

      headers = if pairs.size == classes.size
                  classes
                elsif pairs.size <= classes.size
                  classes.first(pairs.size)
                else
                  return []
                end

      headers.each_with_index.filter_map do |klass, index|
        teacher, subject = pairs[index]
        next unless teacher

        [klass, teacher, subject]
      end
    end

    def class_matches?(klass)
      NameMatcher.classroom_in_text?(klass[:label], @classroom.name) ||
        NameMatcher.serie_and_letter(@classroom.name) == [klass[:serie], klass[:letter].downcase]
    end

    def professor_matches?(teacher)
      NameMatcher.similar?(teacher, @professor_first) ||
        NameMatcher.similar?(teacher, @professor.name)
    end

    def slot_hash(block, teacher, subject)
      {
        period: block[:period],
        start_time: block[:start_time],
        end_time: block[:end_time],
        teacher: teacher,
        subject: subject
      }
    end

    def teacher_subject_pairs(body)
      tokens = body.to_s.split.reject { |token| skip_token?(token) }
      return [] if tokens.blank?

      first_subject = tokens.find_index { |token| subject_known?(token) }
      if first_subject && first_subject >= 3
        grouped = zip_grouped_tokens(tokens, first_subject)
        return grouped if grouped.size >= 3
      end

      pair_interleaved(tokens)
    end

    def zip_grouped_tokens(tokens, first_subject)
      names = chunk_names(tokens[0...first_subject])
      subjects = chunk_subjects(tokens[first_subject..])
      count = [names.size, subjects.size].min
      names.first(count).zip(subjects.first(count))
    end

    def chunk_names(tokens)
      names = []
      tokens.each do |token|
        if names.any? && name_continuation?(token)
          names[-1] = "#{names[-1]} #{token}"
        else
          names << token
        end
      end
      names
    end

    def name_continuation?(token)
      NAME_CONTINUATIONS.include?(NameMatcher.normalize(token))
    end

    def chunk_subjects(tokens)
      subjects = []
      remaining = tokens.dup
      until remaining.empty?
        taken = nil
        3.downto(1) do |length|
          chunk = remaining.first(length).join(" ")
          next unless remaining.size >= length && subject_known?(chunk)

          taken = chunk
          remaining.shift(length)
          break
        end
        if taken
          subjects << taken
        else
          remaining.shift
        end
      end
      subjects
    end

    def pair_interleaved(tokens)
      pairs = []
      teacher = []

      tokens.each do |token|
        if subject_known?(token)
          name = teacher.join(" ").presence || "Professor"
          pairs << [name, token]
          teacher = []
        else
          teacher << token
          teacher = [token] if teacher.size > 4
        end
      end

      pairs
    end

    def subject_known?(text)
      n = NameMatcher.normalize(text)
      return false if n.blank? || n.length < 4
      return false if text.to_s.match?(/\d{2}:\d{2}/) || n.match?(/\d/)
      return true if @courses.any? { |course| NameMatcher.discipline_match?(text, course.name) }
      return true if COMMON_SUBJECTS.any? { |subject| n == subject || (n.length >= 5 && (n.include?(subject) || subject.include?(n))) }

      false
    end
  end
end
