module Students
  class RegistrationNumber
    def self.allocate!(professor, classroom)
      prefix = prefix_for(classroom)
      used = professor.students
                      .where("registration_number LIKE ?", "#{sanitize_like(prefix)}%")
                      .pluck(:registration_number)
      sequence = used.filter_map { |value| value.to_s.delete_prefix(prefix).to_i if value.to_s.start_with?(prefix) }.max.to_i

      loop do
        sequence += 1
        candidate = "#{prefix}#{sequence.to_s.rjust(3, "0")}"
        return candidate unless professor.students.exists?(registration_number: candidate)
      end
    end

    def self.prefix_for(classroom)
      year = classroom.school_year.presence || Date.current.year
      "MAE#{year}#{slug(classroom.name)}"
    end

    def self.slug(name)
      name.to_s
          .unicode_normalize(:nfkd)
          .gsub(/\p{Mn}/, "")
          .upcase
          .gsub(/[^A-Z0-9]/, "")
          .slice(0, 8)
          .presence || "TURMA"
    end

    def self.sanitize_like(value)
      ActiveRecord::Base.sanitize_sql_like(value)
    end
    private_class_method :sanitize_like
  end
end
