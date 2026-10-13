module Siage
  class NameKey
    def self.for(name)
      I18n.transliterate(name.to_s)
          .downcase
          .gsub(/[^a-z0-9]+/, " ")
          .strip
          .squeeze(" ")
    end
  end
end
