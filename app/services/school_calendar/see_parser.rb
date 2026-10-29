require "pdf-reader"
require "zip"

module SchoolCalendar
  class SeeParser
    MONTHS = {
      "janeiro" => 1,
      "fevereiro" => 2,
      "marco" => 3,
      "abril" => 4,
      "maio" => 5,
      "junho" => 6,
      "julho" => 7,
      "agosto" => 8,
      "setembro" => 9,
      "outubro" => 10,
      "novembro" => 11,
      "dezembro" => 12
    }.freeze

    CELL = /\A(?:FM|FI|JP|ODE|RE|RF|CF|SD|I[1-4]B|T[1-4]B|IB|TB|A|F|S|D|X|-{1,2})\z/i
    DATE = %r{(?<day>\d{2})/(?<month>\d{2})/(?<year>\d{4})}
    MAX_SIZE = 12.megabytes

    Result = Data.define(:year, :cells, :holiday_names)

    def initialize(upload)
      @upload = upload
    end

    def parse
      raise ArgumentError, "Anexe o calendário da SEE (PDF ou Excel)." if @upload.blank?
      raise ArgumentError, "O arquivo é grande demais (máximo 12 MB)." if @upload.size.to_i > MAX_SIZE

      name = @upload.original_filename.to_s.downcase
      type = @upload.content_type.to_s

      if name.end_with?(".xlsx", ".xls") || type.include?("spreadsheet") || type.include?("excel")
        parse_xlsx
      else
        parse_pdf
      end
    end

    private

    def io
      file = @upload.tempfile || @upload
      file.rewind if file.respond_to?(:rewind)
      file
    end

    def parse_pdf
      reader = PDF::Reader.new(io)
      year = detect_year(reader)
      raise ArgumentError, "Não encontrei o ano no calendário da SEE." if year.blank?

      runs = reader.pages.flat_map { |page| runs_for(page) }
      columns = day_columns(runs)
      raise ArgumentError, "Não reconheci a tabela de meses e dias da SEE." if columns.size < 28

      cells = {}
      month = nil
      cluster_rows(runs).each do |row|
        break if row.any? { |item| item[:text].match?(/\ADATA\b/i) && item[:x] < 250 }

        month_run = row.find { |item| MONTHS[normalize(item[:text])] && item[:x] < 120 }
        month = MONTHS[normalize(month_run[:text])] if month_run
        next unless month

        row.each do |item|
          code = item[:text].to_s.upcase.gsub(/\s+/, "")
          next unless CELL.match?(code)
          next if item[:x] < 120

          day_number = nearest_day(columns, item[:x])
          next unless day_number

          date = Date.new(year, month, day_number)
          cells[date] = code
        rescue Date::Error, ArgumentError
          next
        end
      end

      raise ArgumentError, "Não encontrei os códigos da SEE neste arquivo." if cells.size < 20

      Result.new(year: year, cells: cells, holiday_names: holiday_names(runs, year))
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
      raise ArgumentError, "Não consegui ler este PDF. Envie o calendário da SEE."
    end

    def parse_xlsx
      path = @upload.respond_to?(:path) ? @upload.path : nil
      raise ArgumentError, "Não consegui ler o Excel da SEE." if path.blank?

      grid = xlsx_grid(path)
      year = detect_year_from_text(grid.flatten.join(" ")) || Date.current.year
      header = grid.find { |row| row.count { |cell| cell.to_s.match?(/\A\d{1,2}\z/) } >= 20 }
      raise ArgumentError, "Não reconheci as colunas de dias no Excel da SEE." if header.blank?

      day_index = {}
      header.each_with_index do |cell, index|
        number = cell.to_s[/\A\d{1,2}\z/]
        next unless number

        day_index[index] = number.to_i if number.to_i.between?(1, 31)
      end

      cells = {}
      grid.each do |row|
        month = row.each_with_index.find do |cell, index|
          index < 3 && MONTHS[normalize(cell.to_s)]
        end
        next unless month

        month_number = MONTHS[normalize(month[0].to_s)]
        day_index.each do |column, day_number|
          code = row[column].to_s.upcase.gsub(/\s+/, "")
          next unless CELL.match?(code)

          date = Date.new(year, month_number, day_number)
          cells[date] = code
        rescue Date::Error, ArgumentError
          next
        end
      end

      raise ArgumentError, "Não encontrei os códigos da SEE neste arquivo." if cells.size < 20

      names = {}
      grid.flatten.each do |cell|
        text = cell.to_s
        match = text.match(DATE)
        next unless match

        date = Date.new(match[:year].to_i, match[:month].to_i, match[:day].to_i)
        label = text.sub(DATE, "").gsub(/segunda-feira|terça-feira|quarta-feira|quinta-feira|sexta-feira|sábado|domingo/i, "").strip
        names[date] = label if label.present?
      rescue Date::Error, ArgumentError
        next
      end

      Result.new(year: year, cells: cells, holiday_names: names)
    end

    def xlsx_grid(path)
      Zip::File.open(path) do |zip|
        sheet = zip.read("xl/worksheets/sheet1.xml")
        shared = []
        if zip.find_entry("xl/sharedStrings.xml")
          shared = parse_shared_strings(zip.read("xl/sharedStrings.xml"))
        end
        parse_sheet_grid(sheet, shared)
      end
    rescue Zip::Error, Nokogiri::XML::SyntaxError
      raise ArgumentError, "Não consegui ler o Excel da SEE."
    end

    def parse_shared_strings(xml)
      document = Nokogiri::XML(xml)
      document.remove_namespaces!
      document.xpath("//si").map { |node| node.xpath(".//t").map(&:text).join }
    end

    def parse_sheet_grid(xml, shared)
      document = Nokogiri::XML(xml)
      document.remove_namespaces!
      document.xpath("//row").map do |row|
        values = {}
        max = 0
        row.xpath("./c").each do |cell|
          ref = cell["r"].to_s
          column = column_index(ref)
          max = column if column > max
          values[column] = xlsx_cell_value(cell, shared)
        end
        Array.new(max + 1) { |index| values[index].to_s.strip }
      end
    end

    def column_index(ref)
      letters = ref.to_s[/[A-Z]+/].to_s
      letters.chars.reduce(0) { |n, char| n * 26 + (char.ord - 64) } - 1
    end

    def xlsx_cell_value(cell, shared)
      type = cell["t"].to_s
      case type
      when "inlineStr"
        cell.xpath(".//t").map(&:text).join
      when "s"
        shared[cell.at_xpath("./v")&.text.to_i].to_s
      else
        cell.at_xpath("./v")&.text.to_s
      end
    end

    def runs_for(page)
      return [] unless page.respond_to?(:runs)

      Array(page.runs).filter_map do |run|
        text = run.text.to_s.gsub(/\s+/, " ").strip
        next if text.blank?

        origin = run.origin
        x = origin.respond_to?(:x) ? origin.x.to_f : run.x.to_f
        y = origin.respond_to?(:y) ? origin.y.to_f : run.y.to_f
        { text: text, x: x, y: y }
      end
    end

    def cluster_rows(runs)
      rows = []
      current = []
      last_y = nil
      runs.sort_by { |item| [-item[:y], item[:x]] }.each do |item|
        if last_y && (last_y - item[:y]).abs > 2.2
          rows << current
          current = []
        end
        current << item
        last_y = item[:y]
      end
      rows << current if current.any?
      rows
    end

    def day_columns(runs)
      header = cluster_rows(runs).find do |row|
        row.any? { |item| item[:text].match?(/MESES/i) } &&
          row.count { |item| item[:text].match?(/\A\d{1,2}\z/) } >= 20
      end
      return {} unless header

      header.filter_map do |item|
        number = item[:text][/\A\d{1,2}\z/]
        next unless number

        day = number.to_i
        next unless day.between?(1, 31)

        [day, item[:x]]
      end.to_h
    end

    def nearest_day(columns, x)
      day, distance = columns.map { |number, column_x| [number, (column_x - x).abs] }.min_by(&:last)
      return if distance.nil? || distance > 22

      day
    end

    def detect_year(reader)
      detect_year_from_text(reader.pages.map(&:text).join(" "))
    end

    def detect_year_from_text(text)
      match = text.to_s.match(/20\d{2}/)
      match && match[0].to_i
    end

    def holiday_names(runs, year)
      names = {}
      cluster_rows(runs).each do |row|
        date_run = row.find { |item| item[:text].match?(DATE) }
        next unless date_run

        match = date_run[:text].match(DATE)
        date = Date.new(match[:year].to_i, match[:month].to_i, match[:day].to_i)
        next unless date.year == year

        label = row
                .reject { |item| item.equal?(date_run) || item[:x] > 540 }
                .map { |item| item[:text] }
                .join(" ")
                .gsub(/segunda-feira|terça-feira|quarta-feira|quinta-feira|sexta-feira|sábado|domingo/i, "")
                .strip
        names[date] = label if label.present?
      rescue Date::Error, ArgumentError
        next
      end
      names
    end

    def normalize(value)
      I18n.transliterate(value.to_s).downcase.gsub(/[^a-z]/, "")
    end
  end
end
