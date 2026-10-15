require "csv"
require "zip"

module Activities
  class SpreadsheetTable
    NS = { "m" => "http://schemas.openxmlformats.org/spreadsheetml/2006/main" }.freeze

    def self.read(path, filename: nil)
      name = filename.to_s.downcase
      return read_csv(path) if name.end_with?(".csv")
      return read_xlsx(path) if name.end_with?(".xlsx") || File.binread(path, 2) == "PK"

      read_csv(path)
    rescue Zip::Error, Nokogiri::XML::SyntaxError
      read_csv(path)
    end

    def self.read_csv(path)
      content = File.read(path, encoding: "bom|utf-8")
      CSV.parse(content, headers: false).map { |row| Array(row).map { |cell| cell.to_s.strip } }
    end

    def self.read_xlsx(path)
      Zip::File.open(path) do |zip|
        shared = shared_strings(zip)
        xml = zip.get_input_stream("xl/worksheets/sheet1.xml", &:read)
        doc = Nokogiri::XML(xml)
        rows = []

        doc.xpath("//m:sheetData/m:row", NS).each do |row_node|
          cells = {}
          row_node.xpath("m:c", NS).each do |cell|
            ref = cell["r"].to_s
            col = column_index(ref)
            cells[col] = cell_value(cell, shared)
          end
          next if cells.empty?

          max = cells.keys.max
          rows << (1..max).map { |index| cells[index].to_s.strip }
        end

        rows
      end
    end

    def self.shared_strings(zip)
      entry = zip.find_entry("xl/sharedStrings.xml")
      return [] unless entry

      doc = Nokogiri::XML(entry.get_input_stream.read)
      doc.xpath("//m:si", NS).map do |si|
        si.xpath(".//m:t", NS).map(&:text).join
      end
    end

    def self.cell_value(cell, shared)
      type = cell["t"]
      value_node = cell.at_xpath("m:v", NS)
      inline = cell.at_xpath("m:is", NS)

      if type == "s" && value_node
        shared[value_node.text.to_i].to_s
      elsif type == "inlineStr" && inline
        inline.xpath(".//m:t", NS).map(&:text).join
      elsif value_node
        value_node.text.to_s
      else
        ""
      end
    end

    def self.column_index(ref)
      letters = ref.to_s[/[A-Z]+/].to_s
      letters.chars.reduce(0) { |n, char| n * 26 + (char.ord - 64) }
    end
  end
end
