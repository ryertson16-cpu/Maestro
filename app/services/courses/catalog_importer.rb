module Courses
  class CatalogImporter
    def initialize(professor:, keys:)
      @professor = professor
      @keys = Array(keys)
    end

    def call
      created = 0

      @keys.each do |key|
        entry = Catalog.find_by_key(key)
        next if entry.blank?
        next unless allowed_area?(entry.knowledge_area)
        next if already_added?(entry)

        @professor.courses.create!(
          name: entry.name,
          knowledge_area: entry.knowledge_area,
          active: true
        )
        created += 1
      end

      created
    end

    private

    def allowed_area?(area)
      Course.available_knowledge_areas_for(@professor).key?(area)
    end

    def already_added?(entry)
      existing.any? do |course|
        course.knowledge_area == entry.knowledge_area &&
          course.name.to_s.unicode_normalize(:nfkc).casecmp?(entry.name)
      end
    end

    def existing
      @existing ||= @professor.courses.to_a
    end
  end
end
