module Lessons
  class WeeklyTimetableImporter
    WEEKDAYS = {
      "segunda" => 1,
      "terca" => 2,
      "quarta" => 3,
      "quinta" => 4,
      "sexta" => 5,
      "sabado" => 6
    }.freeze

    PERIOD_CLOCK = {
      1 => %w[07:30 08:20],
      2 => %w[08:20 09:10],
      3 => %w[09:30 10:20],
      4 => %w[10:20 11:10],
      5 => %w[11:10 12:00],
      6 => %w[13:20 14:10],
      7 => %w[14:10 15:00],
      8 => %w[15:20 16:10],
      9 => %w[16:10 17:00]
    }.freeze

    CLASS_HEADER = /\b(\d+)\s*[ªºa]?\s*s[eé]rie\s+([a-z])\b/i
    MAX_SIZE = 12.megabytes

    def initialize(professor:, upload:)
      @professor = professor
      @upload = upload
    end

    def call
      error = validate
      return { ok: false, error: error } if error

      slots = parse_slots
      if slots.empty?
        first = @professor.name.to_s.split.first
        return {
          ok: false,
          error: "Não encontrei #{first} neste PDF. Confira se o horário é o da escola e se o nome está escrito como no cadastro."
        }
      end

      saved, skipped = persist!(slots)
      {
        ok: true,
        count: saved,
        skipped: skipped,
        message: message_for(saved, skipped, slots.size)
      }
    end

    private

    def validate
      return "Anexe o PDF do horário da escola." if @upload.blank?

      name = @upload.original_filename.to_s
      type = @upload.content_type.to_s
      unless name.match?(/\.pdf\z/i) || type.include?("pdf")
        return "O arquivo precisa ser um PDF."
      end

      return "O PDF é grande demais (máximo 12 MB)." if @upload.size.to_i > MAX_SIZE

      nil
    end

    def parse_slots
      reader = PDF::Reader.new(io)
      reader.pages.flat_map { |page| slots_on_page(page) }
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
      []
    end

    def io
      file = @upload.tempfile
      file.rewind if file.respond_to?(:rewind)
      file
    end

    def slots_on_page(page)
      weekday = weekday_for(page)
      return [] unless weekday

      items = runs_for(page)
      (layout_slots(items, weekday) + text_slots(page, weekday))
        .uniq { |slot| [slot[:weekday], slot[:period], slot[:classroom_label]] }
    end

    def weekday_for(page)
      head = NameMatcher.normalize(page.text.to_s[0, 600])
      WEEKDAYS.each { |key, value| return value if head.include?(key) }
      nil
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

    def layout_slots(items, weekday)
      columns = classroom_columns(items)
      periods = period_rows(items)
      return [] if columns.empty? || periods.empty?

      items.select { |item| professor_hit?(item[:text]) }.filter_map do |name_run|
        col = columns.min_by { |column| (column[:x] - name_run[:x]).abs }
        next if col.blank? || (col[:x] - name_run[:x]).abs > 58

        row = periods.min_by { |period| (period[:y] - name_run[:y]).abs }
        next if row.blank? || (row[:y] - name_run[:y]).abs > 42

        subject = subject_near(items, name_run) || "Componente"
        slot_hash(weekday, row, col[:label], subject, name_run[:text])
      end.uniq { |slot| [slot[:weekday], slot[:period], slot[:classroom_label]] }
    end

    def classroom_columns(items)
      found = []

      items.each do |item|
        match = item[:text].match(CLASS_HEADER)
        next unless match

        found << {
          serie: match[1],
          letter: match[2].upcase,
          x: item[:x],
          label: "#{match[1]}ª SÉRIE #{match[2].upcase}"
        }
      end

      serie_runs = items.select do |item|
        NameMatcher.normalize(item[:text]).match?(/\A\d+\s*a?\s*serie\z/)
      end
      letters = items.select { |item| NameMatcher.normalize(item[:text]).match?(/\A[a-p]\z/) }

      serie_runs.each do |serie_run|
        letter = letters.min_by { |item| (item[:x] - serie_run[:x]).abs + (serie_run[:y] - item[:y]).abs }
        next unless letter && (letter[:x] - serie_run[:x]).abs <= 46

        serie = serie_run[:text][/\d+/]
        letter_ch = NameMatcher.normalize(letter[:text]).upcase
        found << {
          serie: serie,
          letter: letter_ch,
          x: letter[:x],
          label: "#{serie}ª SÉRIE #{letter_ch}"
        }
      end

      found.uniq { |row| "#{row[:serie]}-#{row[:letter]}" }.sort_by { |row| row[:x] }
    end

    def period_rows(items)
      numbers = items.select { |item| item[:x] < 90 && item[:text].match?(/\A[1-9]\z/) }
      times = items.select { |item| item[:x] < 140 && item[:text].match?(/\A\d{2}:\d{2}\z/) }

      rows = numbers.filter_map do |number|
        nearby = times.select { |time| (time[:y] - number[:y]).abs <= 22 }.sort_by { |time| time[:x] }
        clock = PERIOD_CLOCK[number[:text].to_i] || []
        {
          period: number[:text].to_i,
          y: number[:y],
          start_time: nearby[0]&.fetch(:text) || clock[0],
          end_time: nearby[1]&.fetch(:text) || clock[1]
        }
      end

      rows.uniq { |row| row[:period] }.sort_by { |row| -row[:y] }
    end

    def subject_near(items, name_run)
      hit = items
        .select do |item|
          subject_known?(item[:text]) &&
            item[:y] < name_run[:y] - 1 &&
            (name_run[:y] - item[:y]) <= 36 &&
            (item[:x] - name_run[:x]).abs <= 48
        end
        .max_by { |item| item[:y] }
      hit && clean_subject(hit[:text])
    end

    def text_slots(page, weekday)
      text = page.text.to_s.gsub(/[‐–—−]/, "-").gsub(/\s+/, " ")
      classes = text.to_enum(:scan, CLASS_HEADER).map do
        match = Regexp.last_match
        "#{match[1]}ª SÉRIE #{match[2].to_s.upcase}"
      end.uniq
      return [] if classes.size < 8

      parser = TimetableParser.new(
        text: text,
        professor: @professor,
        classroom: Struct.new(:name).new(classes.first),
        courses: @professor.courses.to_a
      )
      blocks = parser.send(:period_blocks)
      blocks.flat_map do |block|
        pairs = parser.send(:teacher_subject_pairs, block[:body])
        count = [pairs.size, classes.size].min
        pairs.first(count).each_with_index.filter_map do |(teacher, subject), index|
          next unless professor_hit?(teacher)
          next unless subject_known?(subject)

          slot_hash(
            weekday,
            {
              period: block[:period],
              start_time: block[:start_time],
              end_time: block[:end_time]
            },
            classes[index],
            subject,
            teacher
          )
        end
      end
    end

    def slot_hash(weekday, row, classroom_label, subject, teacher)
      period = row[:period].to_i
      clock = PERIOD_CLOCK[period] || []
      {
        weekday: weekday,
        period: period,
        start_time: row[:start_time].presence || clock[0],
        end_time: row[:end_time].presence || clock[1],
        classroom_label: classroom_label,
        subject: clean_subject(subject),
        teacher: teacher
      }
    end

    def persist!(slots)
      saved = 0
      skipped = 0

      TimetableEntry.transaction do
        @professor.timetable_entries.delete_all

        slots.each do |slot|
          classroom = match_classroom(slot[:classroom_label])
          unless classroom
            skipped += 1
            next
          end

          course = match_course(slot[:subject])
          entry = @professor.timetable_entries.find_or_initialize_by(
            classroom: classroom,
            weekday: slot[:weekday],
            period: slot[:period]
          )
          entry.course = course
          entry.time_slot = "#{slot[:period]}º tempo"
          entry.save!
          saved += 1
        end
      end

      [saved, skipped]
    end

    def match_classroom(label)
      @classrooms ||= @professor.classrooms.to_a
      wanted = NameMatcher.serie_and_letter(label)
      @classrooms.find do |classroom|
        NameMatcher.classroom_in_text?(label, classroom.name) ||
          NameMatcher.serie_and_letter(classroom.name) == wanted
      end
    end

    def match_course(subject)
      @courses ||= @professor.courses.to_a
      @courses.find { |course| NameMatcher.discipline_match?(subject, course.name) }
    end

    def professor_hit?(text)
      NameMatcher.similar?(text, @professor.name.to_s.split.first) ||
        NameMatcher.similar?(text, @professor.name)
    end

    def subject_known?(text)
      n = NameMatcher.normalize(text)
      return false if n.blank? || n.length < 3
      return false if text.to_s.match?(/\d{2}:\d{2}/)
      return true if match_course(text)
      return true if TimetableParser::COMMON_SUBJECTS.any? do |subject|
        n == subject || (n.length >= 4 && (n.include?(subject) || subject.include?(n)))
      end

      n.match?(/\A(rpp|ppi|estagio|quimica|praticas)/)
    end

    def clean_subject(text)
      text.to_s.gsub(/\d{2}:\d{2}/, "").gsub(/\s+/, " ").strip
    end

    def message_for(saved, skipped, found)
      first = @professor.name.to_s.split.first
      parts = ["Gerei o horário de #{first}: #{saved} aula(s) na grade."]
      parts << "#{skipped} não bateram com turmas cadastradas no Maestro." if skipped.positive?
      parts << "Encontrei #{found} ocorrência(s) no PDF." if found != saved
      parts.join(" ")
    end
  end
end
