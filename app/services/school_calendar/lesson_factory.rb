module SchoolCalendar
  class LessonFactory
    def initialize(professor:, classroom:, starts_on:, ends_on:)
      @professor = professor
      @classroom = classroom
      @starts_on = starts_on
      @ends_on = ends_on
    end

    def call
      created = 0
      skipped = 0
      attendances = 0

      (@starts_on..@ends_on).each do |day|
        next unless school_day?(day)

        entries_for(day).each do |entry|
          lesson = @professor.lessons.find_or_initialize_by(
            classroom: @classroom,
            lesson_date: day,
            course_id: entry.course_id,
            siage_time_slot: entry.time_slot_label
          )

          if lesson.persisted?
            skipped += 1
          else
            course_name = entry.course&.name.presence || "Componente curricular"
            lesson.assign_attributes(
              theme: "Aula de #{course_name}",
              siage_period: Siage.period_for_date(day),
              siage_class_mode: "Aula",
              siage_class_type: "Avulso"
            )
            lesson.save!
            created += 1
          end

          attendances += SchoolCalendar::AttendanceSeeder.new(
            professor: @professor,
            classroom: @classroom,
            lesson: lesson
          ).call
        end
      end

      { created: created, skipped: skipped, attendances: attendances }
    end

    private

    def school_day?(day)
      mark = calendar_index[day]
      return false if mark&.blocks_lessons?
      return true if mark&.kind == "saturday_school"
      return false if day.saturday? || day.sunday?

      true
    end

    def entries_for(day)
      weekday = day.cwday
      return [] if weekday == 7

      timetable.select { |entry| entry.weekday == weekday }
    end

    def timetable
      @timetable ||= @professor.timetable_entries.where(classroom: @classroom).includes(:course)
    end

    def calendar_index
      @calendar_index ||= @professor.school_calendar_days
                                    .where(day: @starts_on..@ends_on)
                                    .index_by(&:day)
    end
  end
end
