module Siage
  class RosterImporter
    Result = Struct.new(:classrooms, :students, :enrollments, :courses, :bindings, keyword_init: true)

    def initialize(professor:, preview:)
      @professor = professor
      @preview = preview.is_a?(Hash) ? preview : {}
    end

    def call
      result = Result.new(classrooms: 0, students: 0, enrollments: 0, courses: 0, bindings: 0)
      year = @preview["school_year"].to_i
      year = Date.current.year if year < 2000

      Array(@preview["classrooms"]).each do |entry|
        classroom = find_or_create_classroom(entry, year, result)
        next unless classroom

        Array(entry["components"]).each do |component|
          course = find_or_create_course(component, result)
          bind!(classroom, course, component, result)
        end

        Array(entry["students"]).each do |row|
          import_student(classroom, row, result)
        end
      end

      result
    end

    private

    def find_or_create_classroom(entry, year, result)
      if entry["existing_classroom_id"].present?
        found = @professor.classrooms.find_by(id: entry["existing_classroom_id"])
        return found if found
      end

      name = entry["name"].to_s.strip
      return if name.blank?

      existing = @professor.classrooms.find { |room| Lessons::NameMatcher.classroom_in_text?(name, room.name) }
      return existing if existing

      grade_name = entry["grade_level"].presence || RosterPreview.grade_level_name(name)
      grade = @professor.grade_levels.where("LOWER(name) = ?", grade_name.downcase).first
      grade ||= @professor.grade_levels.create!(name: grade_name, active: true)
      result.classrooms += 1
      @professor.classrooms.create!(
        name: name,
        school_year: year,
        grade_level: grade,
        active: true
      )
    end

    def find_or_create_course(component, result)
      name = component["componente"].to_s.strip
      return if name.blank?

      if component["existing_course_id"].present?
        found = @professor.courses.find_by(id: component["existing_course_id"])
        return found if found
      end

      existing = @professor.courses.find { |course| Lessons::NameMatcher.discipline_match?(course.name, name) }
      return existing if existing

      result.courses += 1
      @professor.courses.create!(
        name: name,
        knowledge_area: knowledge_area_for(name),
        active: true
      )
    end

    def bind!(classroom, course, component, result)
      turma_id = component["siage_turma_id"].to_s.presence
      binding = if turma_id
        @professor.siage_classroom_bindings.find_or_initialize_by(siage_turma_id: turma_id)
      else
        @professor.siage_classroom_bindings.find_or_initialize_by(
          classroom: classroom,
          course: course,
          componente: component["componente"].to_s
        )
      end
      created = binding.new_record?
      binding.assign_attributes(
        classroom: classroom,
        course: course,
        turma_name: classroom.name,
        componente: component["componente"].to_s.presence
      )
      binding.save!
      result.bindings += 1 if created
    end

    def import_student(classroom, row, result)
      name = row["name"].to_s.strip
      return if name.blank?

      student = if row["existing_student_id"].present?
        @professor.students.find_by(id: row["existing_student_id"])
      end
      student ||= Lessons::NameMatcher.match_student(name, @professor.students.to_a)

      if student.nil?
        student = @professor.students.create!(name: name)
        result.students += 1
      end

      if row["registration_number"].present? && student.registration_number.blank?
        taken = @professor.students.where(registration_number: row["registration_number"]).where.not(id: student.id).exists?
        student.update!(registration_number: row["registration_number"]) unless taken
      end

      if student.registration_number.blank?
        student.update!(registration_number: Students::RegistrationNumber.allocate!(@professor, classroom))
      end

      enrollment = classroom.enrollments.find_by(student_id: student.id)
      return if enrollment

      classroom.enrollments.create!(
        professor: @professor,
        student: student,
        enrolled_on: Date.current,
        status: "active"
      )
      result.enrollments += 1
    end

    def knowledge_area_for(name)
      n = Lessons::NameMatcher.normalize(name)
      return "linguagens_e_codigos" if n.match?(/portug|ingles|espanhol|lingua|arte|redacao|educacao fisica|ed fisica/)
      return "ciencias_humanas" if n.match?(/historia|geografia|filosofia|sociologia|religioso/)
      return "ciencias_da_natureza" if n.match?(/ciencia|biolog|fisica|quimica|natureza/)
      return "base_tecnica" if n.match?(/informatica|administra|tecnica|integrador|inovacao/)

      "matematica"
    end
  end
end
