module Siage
  class RosterPreview
    def initialize(professor:, payload:)
      @professor = professor
      @payload = payload.is_a?(Hash) ? payload : {}
    end

    def as_json(*)
      {
        "school_year" => school_year,
        "classrooms" => grouped_classrooms,
        "empty" => grouped_classrooms.empty?,
        "student_count" => grouped_classrooms.sum { |row| row["students"].size },
        "classroom_count" => grouped_classrooms.size
      }
    end

    private

    def school_year
      Date.current.year
    end

    def rows
      Array(@payload["classrooms"] || @payload[:classrooms])
    end

    def grouped_classrooms
      @grouped_classrooms ||= begin
        groups = {}
        rows.each do |row|
          raw_name = row["name"] || row[:name] || row["turma"] || row[:turma]
          next if raw_name.to_s.strip.blank?

          maestro_name = RosterPreview.maestro_classroom_name(raw_name)
          group = groups[maestro_name] ||= {
            "name" => maestro_name,
            "siage_names" => [],
            "grade_level" => RosterPreview.grade_level_name(raw_name),
            "existing_classroom_id" => existing_classroom_id(maestro_name),
            "components" => [],
            "students" => {}
          }
          group["siage_names"] << raw_name.to_s.strip
          group["siage_names"].uniq!
          group["components"] << component_hash(row)
          Array(row["students"] || row[:students]).each do |student|
            name = (student["name"] || student[:name]).to_s.strip
            next if name.blank?

            key = Lessons::NameMatcher.normalize(name)
            group["students"][key] ||= student_hash(name, student)
          end
        end

        groups.values.map do |group|
          group["components"] = group["components"].uniq { |item| item["componente"].to_s.downcase }
          group["students"] = group["students"].values.sort_by { |item| item["name"] }
          group["action"] = group["existing_classroom_id"] ? "reuse" : "create"
          group
        end.sort_by { |group| group["name"] }
      end
    end

    def component_hash(row)
      componente = (row["componente"] || row[:componente] || row["component"]).to_s.strip
      {
        "componente" => componente,
        "siage_turma_id" => (row["turma_id"] || row["turmaId"] || row[:turma_id]).to_s.presence,
        "existing_course_id" => existing_course_id(componente),
        "action" => existing_course_id(componente) ? "reuse" : "create"
      }
    end

    def student_hash(name, row)
      existing = Lessons::NameMatcher.match_student(name, professor_students)
      {
        "name" => name,
        "registration_number" => (row["registration"] || row["registration_number"] || row[:registration]).to_s.presence,
        "existing_student_id" => existing&.id,
        "action" => existing ? "match" : "create"
      }
    end

    def existing_classroom_id(name)
      rooms = @professor.classrooms.where(school_year: school_year).to_a
      rooms = @professor.classrooms.to_a if rooms.empty?
      found = rooms.find { |room| Lessons::NameMatcher.classroom_in_text?(name, room.name) } ||
              rooms.find { |room| Lessons::NameMatcher.normalize(room.name) == Lessons::NameMatcher.normalize(name) }
      found&.id
    end

    def existing_course_id(name)
      return if name.blank?

      @professor.courses.find { |course| Lessons::NameMatcher.discipline_match?(course.name, name) }&.id
    end

    def professor_students
      @professor_students ||= @professor.students.to_a
    end

    def self.maestro_classroom_name(value)
      pair = Lessons::NameMatcher.serie_and_letter(value)
      return "#{pair[0]}ª #{pair[1].upcase}" if pair.present?

      value.to_s.gsub(/\s+/, " ").strip
    end

    def self.grade_level_name(value)
      pair = Lessons::NameMatcher.serie_and_letter(value)
      return "#{pair[0]}º ano" if pair.present?

      "Série"
    end
  end
end
