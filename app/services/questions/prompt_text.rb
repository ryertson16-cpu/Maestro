module Questions
  class PromptText
    TAGS = %w[b strong i em u s sub sup br p div ul ol li].freeze

    def self.rich?(text)
      text.to_s.match?(/<\s*\/?\s*(?:b|strong|i|em|u|s|sub|sup|br|p|div|ul|ol|li)\b/i)
    end

    def self.sanitized(raw)
      text = raw.to_s.gsub("\u0000", "")
      return text unless rich?(text)

      ActionController::Base.helpers.sanitize(text, tags: TAGS, attributes: [])
    end

    def self.html(raw)
      text = raw.to_s
      return "".html_safe if text.blank?
      return ERB::Util.html_escape(text).gsub("\n", "<br>").html_safe unless rich?(text)

      ActionController::Base.helpers.sanitize(text, tags: TAGS, attributes: []).html_safe
    end

    def self.plain(raw)
      ActionController::Base.helpers.strip_tags(raw.to_s).gsub(/\s+/, " ").strip
    end

    def self.prawn(raw)
      text = sanitized(raw)
      return text unless rich?(text)

      text
        .gsub(/<br\s*\/?>/i, "\n")
        .gsub(/<\/(?:p|div|li)>/i, "\n")
        .gsub(/<li[^>]*>/i, "• ")
        .gsub(/<\/?(?:p|div|ul|ol)[^>]*>/i, "")
        .gsub(/<(strong|b)[^>]*>/i, "<b>")
        .gsub(/<\/(?:strong|b)>/i, "</b>")
        .gsub(/<(em|i)[^>]*>/i, "<i>")
        .gsub(/<\/(?:em|i)>/i, "</i>")
        .gsub(/<u[^>]*>/i, "<u>")
        .gsub(/<\/u>/i, "</u>")
        .gsub(/<(sub|sup)[^>]*>/i, "<\\1>")
        .gsub(/<\/(sub|sup)>/i, "</\\1>")
        .gsub(/<s[^>]*>/i, "<strikethrough>")
        .gsub(/<\/s>/i, "</strikethrough>")
        .gsub(/<[^>]+>/, "")
        .gsub("\n", " ")
        .squeeze(" ")
        .strip
    end
  end
end
