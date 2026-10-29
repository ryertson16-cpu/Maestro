module Enrollments
  class PasteList
    Result = Struct.new(:imported, :created_students, :skipped, :reactivated, :errors, keyword_init: true)

    def initialize(professor:, classroom:, text: nil, rows: nil)
      @professor = professor
      @classroom = classroom
      @text = text.to_s
      @rows = rows
    end

    def call
      errors = []
      imported = 0
      created_students = 0
      skipped = 0
      reactivated = 0

      rows = parse_rows
      if rows.empty?
        return Result.new(
          imported: 0,
          created_students: 0,
          skipped: 0,
          reactivated: 0,
          errors: ["Informe pelo menos um nome (lista colada ou modelo Excel)."]
        )
      end

      Enrollment.transaction do
        rows.each_with_index do |row, index|
          line_number = index + 1
          if row[:name].blank?
            errors << "Linha #{line_number}: o nome é obrigatório."
            next
          end

          student = find_or_initialize_student(row)
          was_new = student.new_record?
          student.name = row[:name]
          student.professor = @professor
          student.active = true
          assign_registration!(student, row[:registration_number])
          student.save!
          created_students += 1 if was_new

          enrollment = @professor.enrollments.find_or_initialize_by(
            student: student,
            classroom: @classroom
          )

          if enrollment.new_record?
            enrollment.assign_attributes(enrolled_on: Date.current, status: "active")
            enrollment.save!
            imported += 1
          elsif enrollment.status != "active"
            enrollment.update!(status: "active", enrolled_on: enrollment.enrolled_on.presence || Date.current)
            reactivated += 1
          else
            skipped += 1
          end
        end

        raise ActiveRecord::Rollback if errors.any?
      end

      Result.new(
        imported: imported,
        created_students: created_students,
        skipped: skipped,
        reactivated: reactivated,
        errors: errors
      )
    end

    def self.parse_line(line)
      stripped = line.to_s.sub(/\A\uFEFF/, "").strip
      return if stripped.blank?
      return if stripped.match?(/\A(nome|name|aluno|matr[ií]cula)\b/i)

      name = stripped
      registration = nil

      if stripped.include?("\t")
        name, registration = stripped.split("\t", 2)
      elsif stripped.include?(";")
        name, registration = stripped.split(";", 2)
      elsif (match = stripped.match(/\A(.+?)[, ]+(\d{3,})\z/))
        name = match[1]
        registration = match[2]
      end

      {
        name: name.to_s.gsub(/\s+/, " ").strip,
        registration_number: registration.to_s.gsub(/\D/, "").presence
      }
    end

    private

    def parse_rows
      return Array(@rows) if @rows

      @text.lines.filter_map { |line| self.class.parse_line(line) }
    end

    def assign_registration!(student, provided)
      number = provided.to_s.gsub(/\D/, "").presence || student.registration_number.presence
      number ||= Students::RegistrationNumber.allocate!(@professor, @classroom)
      student.registration_number = number
    end

    def find_or_initialize_student(row)
      students = @professor.students
      if row[:registration_number].present?
        found = students.find_by(registration_number: row[:registration_number])
        return found if found
      end

      students.find_or_initialize_by(name: row[:name])
    end
  end
end
