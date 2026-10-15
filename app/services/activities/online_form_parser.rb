module Activities
  class OnlineFormParser
    Row = Struct.new(
      :name,
      :classroom_label,
      :raw_score,
      :submitted_at,
      :answers,
      keyword_init: true
    )

    def self.parse(path:, filename: nil)
      new(path, filename).parse
    end

    def initialize(path, filename)
      @path = path
      @filename = filename
    end

    def parse
      table = SpreadsheetTable.read(@path, filename: @filename)
      return [] if table.size < 2

      headers = table.first.map { |cell| cell.to_s.strip }
      name_i = header_index(headers, %w[nome estudante aluno])
      turma_i = header_index(headers, %w[turma])
      score_i = header_index(headers, %w[pontuacao pontuação score nota])
      time_i = header_index(headers, %w[carimbo data hora timestamp])

      question_indexes = headers.each_index.select do |index|
        headers[index].match?(/\A\s*\d+\s*[).:-]/)
      end

      rows = table.drop(1).filter_map do |line|
        name = cell_at(line, name_i)
        next if name.blank?

        Row.new(
          name: name,
          classroom_label: cell_at(line, turma_i),
          raw_score: numeric(cell_at(line, score_i)),
          submitted_at: parse_time(cell_at(line, time_i)),
          answers: question_indexes.filter_map { |index| cell_at(line, index).presence }
        )
      end

      latest_by_name(rows)
    end

    private

    def header_index(headers, needles)
      headers.index do |header|
        normalized = Lessons::NameMatcher.normalize(header)
        needles.any? { |needle| normalized.include?(Lessons::NameMatcher.normalize(needle)) }
      end
    end

    def cell_at(line, index)
      return "" if index.nil?

      line[index].to_s.strip
    end

    def numeric(value)
      text = value.to_s.tr(",", ".").gsub(/[^\d.-]/, "")
      return if text.blank?

      Float(text)
    rescue ArgumentError
      nil
    end

    def parse_time(value)
      text = value.to_s.strip
      return if text.blank?

      if text.match?(/\A\d+(\.\d+)?\z/)
        serial = text.to_f
        return Time.zone.parse("1899-12-30") + serial.days if serial > 20000
      end

      Time.zone.parse(text)
    rescue ArgumentError, TypeError
      nil
    end

    def latest_by_name(rows)
      rows
        .group_by { |row|
          [
            Lessons::NameMatcher.normalize(row.name),
            Lessons::NameMatcher.normalize(row.classroom_label)
          ]
        }
        .values
        .map do |group|
          group.max_by { |row| row.submitted_at || Time.zone.at(0) }
        end
    end
  end
end
