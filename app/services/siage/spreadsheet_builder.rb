require "csv"

module Siage
  class SpreadsheetBuilder
    HEADERS = [
      "Data",
      "Tempos",
      "Turma",
      "Componente",
      "Faltas",
      "Justificados",
      "Id Maestro",
      "Token Maestro",
      "Maestro"
    ].freeze

    def self.for_classroom(professor:, classroom:, origin: nil)
      new(professor: professor, classroom: classroom, origin: origin).csv
    end

    def self.for_lesson(lesson, origin: nil)
      new(professor: lesson.professor, classroom: lesson.classroom, lessons: [lesson], origin: origin).csv
    end

    def self.for_lessons(professor:, lessons:, origin: nil)
      new(professor: professor, classroom: nil, lessons: Array(lessons), origin: origin).csv
    end

    def initialize(professor:, classroom:, lessons: nil, origin: nil)
      @professor = professor
      @classroom = classroom
      @lessons = lessons
      @origin = origin.to_s.presence
    end

    def csv
      "\uFEFF" + CSV.generate(headers: true, col_sep: "\t") do |csv|
        csv << HEADERS
        rows.each { |row| csv << row }
      end
    end

    private

    attr_reader :professor, :classroom

    def extension_token
      @extension_token ||= Siage::ExtensionToken.generate(professor)
    end

    def rows
      lesson_records.map do |lesson|
        [
          lesson.lesson_date.strftime("%d/%m/%Y"),
          tempos_for(lesson),
          turma_label_for(lesson.classroom),
          componente_for(lesson),
          names_for(lesson, :absent),
          names_for(lesson, :justified),
          lesson.id,
          extension_token,
          @origin.to_s
        ]
      end
    end

    def lesson_records
      records =
        if @lessons
          Array(@lessons)
        else
          professor.lessons.where(classroom: classroom).includes(:course, :classroom).order(:lesson_date, :created_at).to_a
        end

      records.sort_by { |lesson| [lesson.classroom.name.to_s, lesson.lesson_date, lesson.created_at] }
    end

    def tempos_for(lesson)
      digits = lesson.siage_time_slot.to_s.scan(/\d+/)
      digits.any? ? digits.join(",") : "1"
    end

    def turma_label_for(room)
      name = room.name.to_s.strip
      return name if name.match?(/s[eé]rie|t[eé]cnic|qualifica|integrado/i)

      if name.match?(/\A\d+\s*[ªºa°]?\s+\S/i)
        name.sub(/\A(\d+)\s*[ªºa°]?\s+/i) { "#{Regexp.last_match(1)}ª SÉRIE " }
      else
        name
      end
    end

    def componente_for(lesson)
      lesson.course&.name.presence ||
        lesson.classroom.course&.name.presence ||
        "Componente curricular"
    end

    def names_for(lesson, status)
      records_for(lesson).select { |record| record.public_send("#{status}?") }
                         .map { |record| record.student.name.to_s.strip }
                         .reject(&:blank?)
                         .uniq
                         .join(" | ")
    end

    def records_for(lesson)
      linked = attendance_by_lesson[lesson.id]
      return linked if linked.present?

      attendance_by_classroom_date[[lesson.classroom_id, lesson.lesson_date]] || []
    end

    def attendance_scope
      @attendance_scope ||= begin
        rooms = lesson_records.map(&:classroom).uniq
        enrollment_ids = Enrollment.where(
          classroom: rooms,
          professor: professor
        ).select(:id)

        AttendanceRecord
          .where(professor: professor, enrollment_id: enrollment_ids)
          .includes(enrollment: :student)
      end
    end

    def attendance_by_lesson
      @attendance_by_lesson ||= attendance_scope.where(lesson_id: lesson_records.map(&:id))
                                                .group_by(&:lesson_id)
    end

    def attendance_by_classroom_date
      @attendance_by_classroom_date ||= attendance_scope.group_by { |record|
        [record.enrollment.classroom_id, record.attendance_date]
      }
    end
  end
end
