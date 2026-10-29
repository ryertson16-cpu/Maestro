require "csv"
require "zip"

module Enrollments
  class ClassroomWorkbook
    NAME_HEADERS = %w[nome name aluno].freeze
    REGISTRATION_HEADERS = %w[matricula matrícula matricula_opcional].freeze

    def self.filename(classroom)
      slug = classroom.name.to_s.parameterize.presence || "turma"
      "Maestro-alunos-#{slug}.xlsx"
    end

    def self.bytes(classroom)
      new(classroom).to_xlsx
    end

    def self.rows_from(uploaded)
      new(nil).rows_from_upload(uploaded)
    end

    def initialize(classroom)
      @classroom = classroom
    end

    def to_xlsx
      Zip::OutputStream.write_buffer do |zip|
        zip.put_next_entry("[Content_Types].xml")
        zip.write(<<~XML)
          <?xml version="1.0" encoding="UTF-8"?>
          <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
            <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          </Types>
        XML
        zip.put_next_entry("_rels/.rels")
        zip.write(<<~XML)
          <?xml version="1.0" encoding="UTF-8"?>
          <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
          </Relationships>
        XML
        zip.put_next_entry("xl/workbook.xml")
        zip.write(<<~XML)
          <?xml version="1.0" encoding="UTF-8"?>
          <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <sheets>
              <sheet name="Alunos" sheetId="1" r:id="rId1"/>
            </sheets>
          </workbook>
        XML
        zip.put_next_entry("xl/_rels/workbook.xml.rels")
        zip.write(<<~XML)
          <?xml version="1.0" encoding="UTF-8"?>
          <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          </Relationships>
        XML
        zip.put_next_entry("xl/worksheets/sheet1.xml")
        zip.write(sheet_xml)
      end.string
    end

    def rows_from_upload(uploaded)
      raise ArgumentError, "Selecione o modelo preenchido." if uploaded.blank?

      name = uploaded.original_filename.to_s.downcase
      path = uploaded.respond_to?(:path) ? uploaded.path : nil
      raise ArgumentError, "Não consegui ler o arquivo." if path.blank?

      if name.end_with?(".csv") || uploaded.content_type.to_s.include?("csv")
        rows_from_csv(path)
      else
        rows_from_xlsx(path)
      end
    end

    private

    def sheet_xml
      rows = [
        ["Nome", "Matrícula (opcional)"]
      ]
      25.times { rows << ["", ""] }

      cells = rows.each_with_index.map do |row, index|
        name = xml_text(row[0])
        registration = xml_text(row[1])
        <<~XML
          <row r="#{index + 1}">
            <c r="A#{index + 1}" t="inlineStr"><is><t>#{name}</t></is></c>
            <c r="B#{index + 1}" t="inlineStr"><is><t>#{registration}</t></is></c>
          </row>
        XML
      end.join

      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            #{cells}
          </sheetData>
        </worksheet>
      XML
    end

    def xml_text(value)
      value.to_s
           .encode(xml: :text)
           .gsub("\n", " ")
    end

    def rows_from_csv(path)
      separator = File.read(path, 2048, encoding: "bom|utf-8").include?(";") ? ";" : ","
      CSV.foreach(path, headers: true, col_sep: separator, encoding: "bom|utf-8").filter_map do |row|
        name = cell_by_header(row, NAME_HEADERS).presence || row[0].to_s.strip
        registration = cell_by_header(row, REGISTRATION_HEADERS).presence || row[1].to_s.strip
        next if name.blank? || name.match?(/\A(nome|name|aluno)\z/i)

        { name: name.gsub(/\s+/, " ").strip, registration_number: registration.to_s.gsub(/\D/, "").presence }
      end
    end

    def cell_by_header(row, names)
      row.headers.each do |header|
        key = header.to_s.downcase.strip
        return row[header].to_s.strip if names.any? { |name| key == name || key.start_with?(name) }
      end
      nil
    end

    def rows_from_xlsx(path)
      Zip::File.open(path) do |zip|
        sheet = zip.read("xl/worksheets/sheet1.xml")
        shared = []
        if zip.find_entry("xl/sharedStrings.xml")
          shared = parse_shared_strings(zip.read("xl/sharedStrings.xml"))
        end
        parse_sheet(sheet, shared)
      end
    end

    def parse_shared_strings(xml)
      document = Nokogiri::XML(xml)
      document.remove_namespaces!
      document.xpath("//si").map { |node| node.xpath(".//t").map(&:text).join }
    end

    def parse_sheet(xml, shared)
      document = Nokogiri::XML(xml)
      document.remove_namespaces!
      document.xpath("//row").filter_map do |row|
        values = { "A" => "", "B" => "" }
        row.xpath("./c").each do |cell|
          ref = cell["r"].to_s.gsub(/\d+/, "")
          values[ref] = cell_value(cell, shared)
        end
        name = values["A"].to_s.gsub(/\s+/, " ").strip
        next if name.blank? || name.match?(/\A(nome|name|aluno)\z/i)
        next if name.match?(/\Amatr[ií]cula/i)

        {
          name: name,
          registration_number: values["B"].to_s.gsub(/\D/, "").presence
        }
      end
    end

    def cell_value(cell, shared)
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
  end
end
