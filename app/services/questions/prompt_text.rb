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

      pending = prefix.to_s
      Nokogiri::HTML.fragment(html).children.each do |node|
        pending = draw_block(pdf, node, prefix: pending, size: size)
      end
      pdf.text pending, size: size if pending.present?
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

    def self.draw_block(pdf, node, prefix:, size:)
      if node.text?
        text = node.text.to_s
        return prefix if text.strip.blank?

        pdf.text "#{prefix}#{escape_inline(text)}", size: size, leading: 2
        return ""
      end

      name = node.name.to_s.downcase
      case name
      when "table"
        pdf.text prefix, size: size if prefix.present?
        draw_table(pdf, node, size)
        ""
      when "img"
        pdf.text prefix, size: size if prefix.present?
        draw_data_image(pdf, node["src"])
        ""
      when "ul", "ol"
        pdf.text prefix, size: size if prefix.present?
        node.css("li").each_with_index do |item, index|
          marker = name == "ol" ? "#{index + 1}. " : "• "
          pdf.text "#{marker}#{inline(item)}", size: size, leading: 2, inline_format: true
        end
        ""
      when "br"
        pdf.move_down 4
        prefix
      else
        pdf.fill_color "20263D"
        pdf.text "#{prefix}#{inline(node)}", size: size, leading: 2, align: alignment(node), inline_format: true
        pdf.move_down 2
        ""
      end
    end

    def self.draw_table(pdf, node, size)
      rows = node.css("tr").filter_map do |row|
        cells = row.css("th, td").map { |cell| inline(cell).presence || " " }
        cells if cells.any?
      end
      return if rows.empty?

      width = rows.map(&:size).max
      rows.each { |row| row << " " while row.size < width }
      pdf.table(rows, width: pdf.bounds.width, cell_style: { inline_format: true, size: size, padding: [3, 4] })
      pdf.move_down 6
    end

    def self.draw_data_image(pdf, src)
      encoded = src.to_s.split(",", 2).last
      return if encoded.blank?

      pdf.image StringIO.new(Base64.decode64(encoded)), fit: [ pdf.bounds.width, 220 ]
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

    private_class_method :scrub, :style_declarations, :draw_block, :draw_table, :draw_data_image,
                         :inline, :inline_node, :alignment, :font_points, :style_value, :color_hex, :escape_inline
  end
end
