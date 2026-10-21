module SchoolCalendar
  class AttendanceSeeder
    def initialize(professor:, classroom:, lesson:)
      @professor = professor
      @classroom = classroom
      @lesson = lesson
    end

    def call
      return 0 unless @lesson&.persisted?

      created = 0
      enrollments.find_each do |enrollment|
        record = AttendanceRecord.find_or_initialize_by(
          professor: @professor,
          enrollment: enrollment,
          attendance_date: @lesson.lesson_date,
          lesson: @lesson
        )
        if record.new_record?
          record.status = "present"
          created += 1
        end
        record.save!
      end
      created
    end

    private

    def enrollments
      Enrollment.where(
        professor: @professor,
        classroom: @classroom,
        status: "active"
      )
    end
  end
end
