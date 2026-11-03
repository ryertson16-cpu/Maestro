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
            "school_course" => nil,
            "shift" => nil,
            "existing_classroom_id" => existing_classroom_id(maestro_name),
            "existing_school_course_id" => nil,
            "components" => [],
            "students" => {}
          }
          group["siage_names"] << raw_name.to_s.strip
          group["siage_names"].uniq!
          group["school_course"] ||= RosterPreview.school_course_name(row, maestro_name, group["grade_level"])
          group["existing_school_course_id"] ||= existing_school_course_id(group["school_course"])
          group["shift"] ||= RosterPreview.shift_from(row["turno"] || row[:turno] || row["shift"] || row[:shift])
          group["components"] << component_hash(row)
          Array(row["students"] || row[:students]).each do |student|
            name = (student["name"] || student[:name]).to_s.strip
            next unless RosterPreview.student_name?(name)

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

    def existing_school_course_id(name)
      return if name.blank?

      @professor.school_courses.find { |course|
        Lessons::NameMatcher.normalize(course.name) == Lessons::NameMatcher.normalize(name)
      }&.id
    end

    def self.school_course_name(row, maestro_name, grade_level)
      qualificacao = (row["qualificacao"] || row[:qualificacao]).to_s.strip
      return qualificacao if qualificacao.present?

      raw = (
        row["curso"] || row[:curso] ||
        row["school_course"] || row[:school_course] ||
        row["etapa"] || row[:etapa]
      ).to_s.strip
      normalized = Lessons::NameMatcher.normalize(raw)
      if raw.present? && !normalized.match?(/\A\d+\s*(o|a)?\s*(ano|serie)/) && normalized != "etapa"
        return raw
      end

      hay = Lessons::NameMatcher.normalize("#{maestro_name} #{grade_level}")
      return "Ensino Médio" if hay.match?(/medio|serie/) || hay.match?(/\b[123]\s*(o|a)?\s*ano/)
      return "Educação Infantil" if hay.match?(/infantil|pre\s*escolar/)
      return "EJA" if hay.match?(/\beja\b/)

      "Ensino Fundamental"
    end

    def self.shift_from(turno)
      n = Lessons::NameMatcher.normalize(turno.to_s)
      return "morning" if n.match?(/manha|matutino/)
      return "afternoon" if n.match?(/tarde|vespertino/)
      return "evening" if n.match?(/noite|noturno/)
      return "full_time" if n.match?(/integral/)

      nil
    end

    def self.student_name?(name)
      n = Lessons::NameMatcher.normalize(name)
      return false if n.blank? || n.length < 5
      return false if n.match?(/\d+\s*(o|a)?\s*periodo/)
      return false if n.match?(/dias letivos|unidade|rec\s*rep/)
      return false if n.match?(/\A\d{1,2}\s+\d{1,2}\s+\d{2,4}\z/)

      n.split.size >= 2
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
