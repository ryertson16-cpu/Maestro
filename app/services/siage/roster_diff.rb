module Siage
  class RosterDiff
    Row = Struct.new(
      :student,
      :enrollment,
      :maestro_classroom,
      :siage_classroom,
      :siage_classroom_name,
      :siage_course,
      :siage_name,
      keyword_init: true
    )

    def initialize(professor:, payload:)
      @professor = professor
      @payload = payload.is_a?(Hash) ? payload : {}
    end

    def empty?
      seats.empty?
    end

    def wrong_classroom
      @wrong_classroom ||= begin
        rows = []
        active_enrollments.each do |enrollment|
          found = seats_for(enrollment.student)
          next if found.empty?
          next if found.any? { |seat| seat.classroom&.id == enrollment.classroom_id }

          seat = found.first
          rows << Row.new(
            student: enrollment.student,
            enrollment: enrollment,
            maestro_classroom: enrollment.classroom,
            siage_classroom: seat.classroom,
            siage_classroom_name: seat.classroom_name,
            siage_course: seat.school_course,
            siage_name: seat.name
          )
        end
        rows.sort_by { |row| [ row.maestro_classroom.name, row.student.name ] }
      end
    end

    def only_maestro
      @only_maestro ||= active_enrollments.filter_map { |enrollment|
        next if seats_for(enrollment.student).any?

        Row.new(
          student: enrollment.student,
          enrollment: enrollment,
          maestro_classroom: enrollment.classroom,
          siage_classroom: nil,
          siage_classroom_name: nil,
          siage_course: nil,
          siage_name: nil
        )
      }.sort_by { |row| [ row.maestro_classroom.name, row.student.name ] }
    end

    def only_siage
      @only_siage ||= seats.filter_map { |seat|
        student = match_student(seat.name)
        next if student && active_enrollments.any? { |enrollment|
          enrollment.student_id == student.id &&
            (seat.classroom.nil? || enrollment.classroom_id == seat.classroom.id)
        }
        next if student && wrong_classroom.any? { |row| row.student.id == student.id }

        Row.new(
          student: student,
          enrollment: nil,
          maestro_classroom: nil,
          siage_classroom: seat.classroom,
          siage_classroom_name: seat.classroom_name,
          siage_course: seat.school_course,
          siage_name: seat.name
        )
      }.sort_by { |row| [ row.siage_classroom_name.to_s, row.siage_name.to_s ] }
    end

    def matched_count
      active_enrollments.count { |enrollment|
        seats_for(enrollment.student).any? { |seat| seat.classroom&.id == enrollment.classroom_id }
      }
    end

    private

    Seat = Struct.new(:name, :classroom_name, :school_course, :classroom, keyword_init: true)

    def seats
      @seats ||= begin
        list = []
        Array(@payload["classrooms"] || @payload[:classrooms]).each do |row|
          raw_name = row["name"] || row[:name] || row["turma"] || row[:turma]
          next if raw_name.to_s.strip.blank?

          maestro_name = RosterPreview.maestro_classroom_name(raw_name)
          grade = RosterPreview.grade_level_name(raw_name)
          school_course = RosterPreview.school_course_name(row, maestro_name, grade)
          classroom = find_classroom(maestro_name, school_course)

          Array(row["students"] || row[:students]).each do |student|
            name = (student["name"] || student[:name]).to_s.strip
            next unless RosterPreview.student_name?(name)

            list << Seat.new(
              name: name,
              classroom_name: maestro_name,
              school_course: school_course,
              classroom: classroom
            )
          end
        end
        list
      end
    end

    def active_enrollments
      @active_enrollments ||= @professor.enrollments
        .where(status: "active")
        .includes(:student, classroom: :school_course)
        .to_a
    end

    def students
      @students ||= @professor.students.includes(:enrollments).to_a
    end

    def match_student(name)
      Lessons::NameMatcher.match_student(name, students)
    end

    def seats_for(student)
      seats_by_student_id[student.id] || []
    end

    def seats_by_student_id
      @seats_by_student_id ||= seats.each_with_object(Hash.new { |hash, key| hash[key] = [] }) { |seat, map|
        found = match_student(seat.name)
        map[found.id] << seat if found
      }
    end

    def find_classroom(name, school_course_name)
      rooms = @professor.classrooms.includes(:school_course).to_a
      wanted_course = Lessons::NameMatcher.normalize(school_course_name.to_s)
      rooms.find { |room|
        name_ok = Lessons::NameMatcher.classroom_in_text?(name, room.name) ||
                  Lessons::NameMatcher.normalize(room.name) == Lessons::NameMatcher.normalize(name)
        next unless name_ok
        next true if wanted_course.blank? || room.school_course.blank?

        Lessons::NameMatcher.normalize(room.school_course.name) == wanted_course
      } || rooms.find { |room|
        Lessons::NameMatcher.classroom_in_text?(name, room.name) ||
          Lessons::NameMatcher.normalize(room.name) == Lessons::NameMatcher.normalize(name)
      }
    end
  end
end
