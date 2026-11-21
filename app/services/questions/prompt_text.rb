require "nokogiri"
require "base64"
require "stringio"

module Questions
  class PromptText
    TAGS = %w[b strong i em u s strike sub sup br p div ul ol li span font table thead tbody tr td th img].freeze
    ATTRIBUTES = %w[style color size src alt colspan rowspan align].freeze
    FONT_POINTS = { "1" => 8, "2" => 10, "3" => 12, "4" => 14, "5" => 18, "6" => 24, "7" => 32 }.freeze

    def self.rich?(text)
      text.to_s.match?(%r{<\s*/?\s*(?:#{TAGS.join("|")})\b}i)
    end

    def self.sanitized(raw)
      text = raw.to_s.gsub("\u0000", "")
      return text unless text.match?(/</)

      cleaned = ActionController::Base.helpers.sanitize(text, tags: TAGS, attributes: ATTRIBUTES)
      scrub(cleaned)
    end

    def self.html(raw)
      text = raw.to_s
      return "".html_safe if text.blank?
      return ERB::Util.html_escape(text).gsub("\n", "<br>").html_safe unless rich?(text)

      sanitized(text).html_safe
    end

    def self.plain(raw)
      ActionController::Base.helpers.strip_tags(raw.to_s).gsub(/\s+/, " ").strip
    end

    def self.prawn(raw)
      text = sanitized(raw)
      return text unless rich?(text)

      text
        .gsub(/<br\s*\/?>/i, "\n")
        .gsub(/<\/(?:p|div|li|tr)>/i, "\n")
        .gsub(/<li[^>]*>/i, "• ")
        .gsub(/<t[dh][^>]*>/i, " ")
        .gsub(%r{</?(?:p|div|ul|ol|table|thead|tbody|tr|td|th|span|font|img)[^>]*>}i, "")
        .gsub(/<(strong|b)[^>]*>/i, "<b>")
        .gsub(%r{</(?:strong|b)>}i, "</b>")
        .gsub(/<(em|i)[^>]*>/i, "<i>")
        .gsub(%r{</(?:em|i)>}i, "</i>")
        .gsub(/<u[^>]*>/i, "<u>")
        .gsub(%r{</u>}i, "</u>")
        .gsub(/<(sub|sup)[^>]*>/i, "<\\1>")
        .gsub(%r{</(sub|sup)>}i, "</\\1>")
        .gsub(/<(?:s|strike)[^>]*>/i, "<strikethrough>")
        .gsub(%r{</(?:s|strike)>}i, "</strikethrough>")
        .gsub(/<[^>]+>/, "")
        .gsub("\n", " ")
        .squeeze(" ")
        .strip
    end

    def self.draw(pdf, raw, prefix:, size:)
      html = sanitized(raw)
      pdf.fill_color "20263D"
      unless rich?(html)
        pdf.text "#{prefix}#{html}", size: size, leading: 2
        return
      end

      draw_flow(pdf, Nokogiri::HTML.fragment(html), prefix: prefix.to_s, size: size, align: :left)
    end

    def self.scrub(html)
      fragment = Nokogiri::HTML.fragment(html)
      fragment.css("[style]").each do |node|
        kept = style_declarations(node["style"])
        if kept.empty?
          node.remove_attribute("style")
        else
          node["style"] = kept.join("; ")
        end
      end
      fragment.css("font").each do |node|
        node.remove_attribute("size") unless FONT_POINTS.key?(node["size"].to_s)
        node.remove_attribute("color") unless color_hex(node["color"])
      end
      fragment.css("img").each do |node|
        src = node["src"].to_s
        node.remove if src.blank? || !src.match?(%r{\Adata:image/(?:png|jpeg|jpg|gif|webp);base64,}i)
      end
      fragment.to_html
    end

    def self.style_declarations(style)
      style.to_s.split(";").filter_map do |declaration|
        name, value = declaration.split(":", 2).map { |part| part.to_s.strip }
        next if name.blank? || value.blank?

        case name.downcase
        when "text-align"
          align = value.downcase
          "text-align: #{align}" if %w[left right center justify].include?(align)
        when "color"
          hex = color_hex(value)
          "color: ##{hex}" if hex
        when "font-size"
          points = value[/\A(\d{1,2}(?:\.\d+)?)(?:px|pt)\z/i, 1]
          "font-size: #{points}pt" if points && points.to_f.between?(8, 48)
        end
      end
    end

    def self.draw_flow(pdf, node, prefix:, size:, align:)
      buffer = prefix.to_s
      buffer_align = align
      node.children.each do |child|
        name = child.name.to_s.downcase
        if child.text? || inline_tag?(child)
          piece = child.text? ? escape_inline(child.text.to_s) : inline_node(child)
          buffer = join_piece(buffer, piece.gsub(/[ \t]*\n[ \t]*/, " "))
        elsif name == "br"
          buffer = join_piece(buffer, "\n")
        elsif paragraph_tag?(name) && !complex_block?(child)
          text = inline(child).gsub(/[ \t]*\n[ \t]*/, "\n").gsub(/[ \t]{2,}/, " ").strip
          if text.blank?
            write_flow(pdf, buffer, size, buffer_align)
            buffer = ""
            pdf.move_down 8
            next
          end

          child_align = alignment(child)
          if buffer.present? && flow_continues?(buffer, text, buffer_align, child_align)
            buffer = "#{buffer.rstrip} #{text}"
            buffer_align = child_align
          else
            write_flow(pdf, buffer, size, buffer_align)
            pdf.move_down 8 unless buffer.blank?
            buffer = text
            buffer_align = child_align
          end
        else
          write_flow(pdf, buffer, size, buffer_align)
          pdf.move_down 8 unless buffer.blank?
          buffer = ""
          draw_structural(pdf, child, size)
        end
      end
      write_flow(pdf, buffer, size, buffer_align)
    end

    def self.draw_structural(pdf, node, size)
      name = node.name.to_s.downcase
      case name
      when "table"
        draw_table(pdf, node, size)
      when "img"
        draw_data_image(pdf, node["src"])
      when "ul", "ol"
        node.element_children.each_with_index do |item, index|
          next unless item.name.to_s.downcase == "li"

          marker = name == "ol" ? "#{index + 1}. " : "• "
          text = inline(item).gsub(/\s+/, " ").strip
          pdf.text "#{marker}#{text}", size: size, leading: 2, inline_format: true
          pdf.move_down 6
        end
      else
        draw_flow(pdf, node, prefix: "", size: size, align: alignment(node))
        pdf.move_down 4
      end
    end

    def self.inline_tag?(node)
      %w[span font b strong i em u s strike sub sup a].include?(node.name.to_s.downcase)
    end

    def self.paragraph_tag?(name)
      %w[div p blockquote h1 h2 h3 h4 h5 h6].include?(name)
    end

    def self.complex_block?(node)
      node.element_children.any? { |child| !inline_tag?(child) && child.name.to_s.downcase != "br" }
    end

    def self.join_piece(buffer, piece)
      return buffer if piece.blank?
      return piece if buffer.blank?
      return buffer if piece.strip.blank? && buffer.end_with?(" ")

      needs_space = !buffer.end_with?(" ", "\n") && !piece.start_with?(" ", "\n")
      "#{buffer}#{needs_space ? ' ' : ''}#{piece}"
    end

    def self.flow_continues?(buffer, text, align, next_align)
      return true if buffer.match?(/\A\s*\d+\.\s*\z/)
      return false unless align == next_align

      plain_next = text.gsub(/<[^>]+>/, "").lstrip
      return true if plain_next.match?(/\A[[:lower:]]/)

      plain = buffer.gsub(/<[^>]+>/, "")
      return false if plain.match?(/[.!?]\s*\z/)

      plain.length > 40
    end

    def self.write_flow(pdf, text, size, align)
      chunks = []
      text.to_s.split("\n").each do |line|
        cleaned = line.gsub(/[ \t]{2,}/, " ").strip
        next if cleaned.blank?

        if chunks.last && flow_continues?(chunks.last, cleaned, align, align)
          chunks[-1] = "#{chunks.last.rstrip} #{cleaned}"
        else
          chunks << cleaned
        end
      end

      chunks.each_with_index do |chunk, index|
        pdf.move_down 8 if index.positive?
        caption, body = peel_aligned_body(chunk, align)
        pdf.text caption, size: size, leading: 2, align: align, inline_format: caption.match?(/<[a-z]/i)
        next if body.blank?

        pdf.move_down 8
        pdf.text body, size: size, leading: 2, align: :left, inline_format: body.match?(/<[a-z]/i)
      end
    end

    def self.peel_aligned_body(text, align)
      return [text, nil] unless %i[right center].include?(align)

      plain = text.gsub(/<[^>]+>/, "")
      cut = plain.rindex(/\.\s+(?=\p{Lu})/)
      return [text, nil] unless cut

      tail = plain[(cut + 1)..].to_s.strip
      return [text, nil] if tail.length < 30
      return [text, nil] if tail.match?(/https?:|Dispon[ií]vel|Acesso em|adaptado/i)

      head = slice_plain(text, 0, cut + 1).strip
      body = slice_plain(text, cut + 1, plain.length).strip
      return [text, nil] if head.blank? || body.blank?

      [head, body]
    end

    def self.slice_plain(text, start_plain, end_plain)
      plain_index = 0
      pieces = text.to_s.scan(/<[^>]+>|[^<]+/).filter_map do |piece|
        if piece.start_with?("<")
          piece
        else
          kept = +""
          piece.each_char do |char|
            kept << char if plain_index >= start_plain && plain_index < end_plain
            plain_index += 1
          end
          kept
        end
      end
      pieces.join.gsub(/<(?!\/)[^>]*>\s*<\/[^>]+>/, "").strip
    end

    def self.rich_cell?(cell)
      return true if alignment(cell) != :left

      cell.css("div, p, ul, ol, blockquote, h1, h2, h3, h4, h5, h6").any? ||
        cell.css("[align], [style]").any? { |node| alignment(node) != :left }
    end

    def self.draw_table(pdf, node, size)
      row_nodes = node.css("tr").filter_map do |row|
        cells = row.css("th, td").to_a
        cells if cells.any?
      end
      if row_nodes.all?(&:one?) && row_nodes.any? { |row| rich_cell?(row.first) }
        row_nodes.each do |row|
          draw_flow(pdf, row.first, prefix: "", size: size, align: alignment(row.first))
          pdf.move_down 4
        end
        return
      end

      rows = row_nodes.map { |row| row.map { |cell| inline(cell).gsub(/\s+/, " ").strip.presence || " " } }
      return if rows.empty?

      width = rows.map(&:size).max
      rows.each { |row| row << " " while row.size < width }
      pdf.table(rows, width: pdf.bounds.width, cell_style: { inline_format: true, size: size, padding: [3, 4] })
      pdf.move_down 6
    end

    def self.draw_data_image(pdf, src)
      encoded = src.to_s.split(",", 2).last
      return if encoded.blank?

      pdf.image StringIO.new(Base64.decode64(encoded)), fit: [ pdf.bounds.width, 320 ]
      pdf.move_down 6
    rescue StandardError
      nil
    end

    def self.inline(node)
      node.children.map { |child| inline_node(child) }.join
    end

    def self.inline_node(node)
      return escape_inline(node.text) if node.text?

      inner = inline(node)
      case node.name.to_s.downcase
      when "b", "strong" then "<b>#{inner}</b>"
      when "i", "em" then "<i>#{inner}</i>"
      when "u" then "<u>#{inner}</u>"
      when "s", "strike" then "<strikethrough>#{inner}</strikethrough>"
      when "sub" then "<sub>#{inner}</sub>"
      when "sup" then "<sup>#{inner}</sup>"
      when "br" then "\n"
      when "font", "span"
        colored = color_hex(node["color"]) || color_hex(style_value(node["style"], "color"))
        points = font_points(node)
        inner = "<color rgb=\"#{colored}\">#{inner}</color>" if colored
        inner = "<font size=\"#{points}\">#{inner}</font>" if points
        inner
      else
        inner
      end
    end

    def self.alignment(node)
      value = style_value(node["style"], "text-align").presence || node["align"].to_s
      case value.downcase
      when "center" then :center
      when "right" then :right
      when "justify" then :justify
      else :left
      end
    end

    def self.font_points(node)
      mapped = FONT_POINTS[node["size"].to_s]
      return mapped if mapped

      points = style_value(node["style"], "font-size")[/\A(\d{1,2}(?:\.\d+)?)(?:px|pt)\z/i, 1]
      points.to_f.round if points && points.to_f.between?(8, 48)
    end

    def self.style_value(style, property)
      style.to_s[/#{Regexp.escape(property)}\s*:\s*([^;]+)/i, 1].to_s.strip
    end

    def self.color_hex(value)
      text = value.to_s.strip
      hex = text[/\A#?([0-9a-f]{6})\z/i, 1]
      return hex.upcase if hex

      short = text[/\A#([0-9a-f]{3})\z/i, 1]
      return short.chars.map { |char| char * 2 }.join.upcase if short

      rgb = text.match(/\Argb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)\z/i)
      return unless rgb

      rgb.captures.map { |part| format("%02X", part.to_i.clamp(0, 255)) }.join
    end

    def self.escape_inline(text)
      text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end

    private_class_method :scrub, :style_declarations, :draw_flow, :draw_structural, :draw_table,
                         :draw_data_image, :inline, :inline_node, :inline_tag?, :paragraph_tag?,
                         :complex_block?, :join_piece, :flow_continues?, :write_flow, :peel_aligned_body,
                         :slice_plain, :rich_cell?, :alignment,
                         :font_points, :style_value, :color_hex, :escape_inline
  end
end
