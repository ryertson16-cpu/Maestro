require "zip"

module Documents
  class ActivityDocx
    def initialize(professor:, activity:, correction_url: nil, students: [], student_url: nil, mode: :student)
      @professor = professor
      @activity = activity
      @lesson = activity.lesson
      @classroom = @lesson.classroom
      @students = Array(students)
      @mode = mode.to_s == "answer_key" ? :answer_key : :student
      @assigner = Activities::ExamAssigner.new(activity)
    end

    def render
      buffer = Zip::OutputStream.write_buffer do |zip|
        zip.put_next_entry("[Content_Types].xml")
        zip.write(content_types)
        zip.put_next_entry("_rels/.rels")
        zip.write(root_rels)
        zip.put_next_entry("word/document.xml")
        zip.write(document_xml)
        zip.put_next_entry("word/_rels/document.xml.rels")
        zip.write(document_rels)
      end
      buffer.rewind
      buffer.read
    end

    private

    def answer_key?
      @mode == :answer_key
    end

    def document_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            #{body}
            <w:sectPr>
              <w:pgSz w:w="11906" w:h="16838"/>
              <w:pgMar w:top="794" w:right="794" w:bottom="794" w:left="794"/>
            </w:sectPr>
          </w:body>
        </w:document>
      XML
    end

    def body
      return key_body if answer_key?
      return blank_body if @students.empty?

      @students.map.with_index { |student, index| student_body(student, page_break: index.positive?) }.join
    end

    def student_body(student, page_break:)
      presented = @assigner.presented_for(student)
      parts = []
      parts << page_break_xml if page_break
      parts << paragraph(school_name, bold: true)
      parts << paragraph(heading)
      parts << paragraph(@activity.title.to_s, bold: true)
      parts << paragraph(student.name.to_s, bold: true)
      parts << paragraph(meta)
      parts << source_text_xml
      presented.each { |row| parts << question_xml(row, show_key: false) }
      rows = omr_rows(presented)
      if rows.any?
        parts << paragraph("Gabarito", bold: true)
        parts << gabarito_table(rows)
        parts << paragraph("Pinte um círculo por questão.")
      end
      parts.join
    end

    def key_body
      slots = @activity.exam_assignments.includes(:student).group_by(&:slot).sort_by(&:first)
      return blank_body if slots.empty?

      slots.map.with_index do |(slot, rows), index|
        sample = rows.first
        presented = @assigner.present(sample)
        names = rows.filter_map { |row| row.student&.name }.sort
        parts = []
        parts << page_break_xml if index.positive?
        parts << paragraph(school_name, bold: true)
        parts << paragraph(heading)
        parts << paragraph(@activity.title.to_s, bold: true)
        parts << paragraph("Folha #{slot}")
        parts << paragraph(names.join(", "))
        parts << source_text_xml
        presented.each { |row| parts << question_xml(row, show_key: true) }
        omr = omr_rows(presented)
        parts << gabarito_table(omr) if omr.any?
        parts.join
      end.join
    end

    def blank_body
      [
        paragraph(school_name, bold: true),
        paragraph(heading),
        paragraph(@activity.title.to_s, bold: true),
        paragraph(meta)
      ].join
    end

    def question_xml(row, show_key:)
      item = row.item
      lead = "#{row.number}. "
      parts = [
        if Questions::PromptText.rich?(item.prompt)
          "<w:p>#{run(lead, bold: true)}#{runs_for(item.prompt, bold: false)}</w:p>"
        else
          paragraph("#{lead}#{item.prompt}")
        end
      ]
      if show_key && item.objective?
        parts << paragraph("Resposta: #{row.printed_correct}", bold: true)
      end
      row.pairs.each do |letter, text|
        parts << paragraph("#{letter}) #{text}")
      end
      parts.join
    end

    def gabarito_table(rows)
      columns = @activity.printed_card_columns(rows.size)
      per_column = (rows.size / columns.to_f).ceil
      groups = rows.each_slice(per_column).to_a
      height = groups.map(&:size).max.to_i
      lines = height.times.map do |index|
        cells = groups.map do |group|
          row = group[index]
          text = row ? "#{row[:number]}    #{row[:letters].map { |letter| "(#{letter})" }.join('  ')}" : ""
          "<w:tc><w:p>#{run(text)}</w:p></w:tc>"
        end
        "<w:tr>#{cells.join}</w:tr>"
      end
      "<w:tbl>#{lines.join}</w:tbl>"
    end

    def omr_rows(presented)
      presented.filter_map do |row|
        next unless row.item.objective?

        letters = row.pairs.map(&:first).presence || Question::LETTERS
        { number: row.number, letters: letters }
      end
    end

    def source_text_xml
      body = @activity.source_text.to_s
      return "" if Questions::PromptText.plain(body).blank?

      [paragraph("Texto", bold: true), paragraph(body)].join
    end

    def paragraph(text, bold: false, rich: nil)
      source = rich.present? ? rich : text
      "<w:p>#{runs_for(source, bold: bold)}</w:p>"
    end

    def runs_for(source, bold:)
      return run(source, bold: bold) unless Questions::PromptText.rich?(source)

      text = Questions::PromptText.sanitized(source)
        .gsub(/<br\s*\/?>/i, "\n")
        .gsub(/<\/(?:p|div|li)>/i, "\n")
        .gsub(/<li[^>]*>/i, "• ")
        .gsub(/<\/?(?:p|div|ul|ol)[^>]*>/i, "")
      state = { bold: bold, italic: false, underline: false, strike: false, sub: false, sup: false }
      marks = { "b" => :bold, "strong" => :bold, "i" => :italic, "em" => :italic, "u" => :underline, "s" => :strike, "sub" => :sub, "sup" => :sup }
      text.scan(/<[^>]+>|[^<]+/).filter_map { |token|
        if token.start_with?("<")
          name = token.sub(%r{\A</?\s*}, "").sub(/[\s>].*\z/, "").downcase
          key = marks[name]
          state[key] = !token.match?(%r{\A<\s*/}) if key
          next
        end

        run(token, **state)
      }.join
    end

    def run(text, bold: false, italic: false, underline: false, strike: false, sub: false, sup: false)
      value = escape(text.to_s)
      return "" if value.blank?

      props = []
      props << "<w:b/>" if bold
      props << "<w:i/>" if italic
      props << "<w:u w:val=\"single\"/>" if underline
      props << "<w:strike/>" if strike
      props << "<w:vertAlign w:val=\"subscript\"/>" if sub
      props << "<w:vertAlign w:val=\"superscript\"/>" if sup
      style = props.any? ? "<w:rPr>#{props.join}</w:rPr>" : ""
      "<w:r>#{style}<w:t xml:space=\"preserve\">#{value}</w:t></w:r>"
    end

    def page_break_xml
      "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
    end

    def school_name
      @professor.school&.name.presence || "Maestro"
    end

    def heading
      base = @activity.adapted? ? "#{@activity.activity_type} · ADAPTADA" : @activity.activity_type
      answer_key? ? "Gabarito · #{base}" : base.to_s
    end

    def meta
      [ @classroom&.name, @lesson.course&.name ].compact.join("  ·  ")
    end

    def escape(text)
      text.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
    end

    def content_types
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
      XML
    end

    def root_rels
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
      XML
    end

    def document_rels
      <<~XML
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
      XML
    end
  end
end
