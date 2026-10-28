module Lessons
  class DayLessonsFromTimetable
    def initialize(professor:, lesson_date:, upload: nil, classroom: nil)
      @professor = professor
      @lesson_date = lesson_date
      @upload = upload
      @classroom = classroom
    end

    def call
      imported = import_if_needed
      return imported if imported && !imported[:ok]

      entries = day_entries
      if entries.empty?
        first = @professor.name.to_s.split.first
        return {
          ok: false,
          error: "Não achei aula de #{first} neste dia da semana. Anexe o PDF do horário da escola ou gere a grade em Meu horário."
        }
      end

      created = 0
      skipped = 0
      attendances = 0
      classrooms = entries.map(&:classroom).uniq.sort_by(&:name)

      classrooms.each do |classroom|
        result = SchoolCalendar::LessonFactory.new(
          professor: @professor,
          classroom: classroom,
          starts_on: @lesson_date,
          ends_on: @lesson_date
        ).call
        created += result[:created].to_i
        skipped += result[:skipped].to_i
        attendances += result[:attendances].to_i
      end

      {
        ok: true,
        created: created,
        skipped: skipped,
        attendances: attendances,
        classrooms: classrooms.map { |classroom| { id: classroom.id, name: classroom.name } },
        preview: imported&.dig(:preview),
        identity: imported&.dig(:identity) || identity_label,
        message: message_for(created, skipped, classrooms, imported, entries)
      }
    end

    private

    def import_if_needed
      return if @upload.blank?

      WeeklyTimetableImporter.new(professor: @professor, upload: @upload).call
    end

    def day_entries
      scope = @professor.timetable_entries
                        .includes(:classroom, :course)
                        .where(weekday: @lesson_date.cwday)
      scope = scope.where(classroom: @classroom) if @classroom
      scope.order(:period)
    end

    def identity_label
      names = @professor.timetable_search_names.join(" / ")
      disciplines = @professor.timetable_discipline_names.join(", ")
      [names.presence, disciplines.presence].compact.join(" · ")
    end

    def message_for(created, skipped, classrooms, imported, entries)
      names = classrooms.map(&:name).join(", ")
      tempos = entries.map { |entry| "#{entry.period}º #{entry.classroom.name}" }.join(", ")
      parts = []
      parts << imported[:message] if imported&.dig(:ok)
      parts << "Identidade no horário: #{identity_label}."
      parts << "Criei #{created} aula(s) de #{I18n.l(@lesson_date)}: #{tempos.presence || names}."
      parts << "#{skipped} já existiam." if skipped.positive?
      parts.join(" ")
    end
  end
end
