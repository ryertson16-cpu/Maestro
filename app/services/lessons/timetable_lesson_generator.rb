module Lessons
  class TimetableLessonGenerator
    WEEKDAYS = {
      0 => "domingo",
      1 => "segunda",
      2 => "terca",
      3 => "quarta",
      4 => "quinta",
      5 => "sexta",
      6 => "sabado"
    }.freeze

    def initialize(professor:, classroom:, lesson_date:, upload:, course: nil)
      @professor = professor
      @classroom = classroom
      @lesson_date = lesson_date
      @upload = upload
      @selected_course = course
    end

    def call
      imported = import_if_needed
      return imported if imported && !imported[:ok]

      entries = classroom_entries
      if entries.empty?
        first = @professor.name.to_s.split.first
        return {
          ok: false,
          error: "Não encontrei #{first} na #{@classroom.name} neste dia da semana. Confira a data e o PDF do horário da escola."
        }
      end

      course = pick_course(entries)
      payload_for(course, entries, imported)
    end

    private

    def import_if_needed
      return if @upload.blank?
      return { ok: false, error: validate_upload } if validate_upload

      WeeklyTimetableImporter.new(professor: @professor, upload: @upload).call
    end

    def validate_upload
      name = @upload.original_filename.to_s
      type = @upload.content_type.to_s
      unless name.match?(/\.pdf\z/i) || type.include?("pdf")
        return "O arquivo precisa ser um PDF."
      end

      return "O PDF é grande demais (máximo 12 MB)." if @upload.size.to_i > 12.megabytes

      nil
    end

    def classroom_entries
      @professor.timetable_entries
                .includes(:course)
                .where(classroom: @classroom, weekday: @lesson_date.cwday)
                .order(:period)
    end

    def own_courses
      listed = @professor.courses.to_a
      listed << @selected_course if @selected_course
      listed.compact.uniq(&:id)
    end

    def pick_course(entries)
      catalog = own_courses
      return @selected_course if @selected_course && catalog.include?(@selected_course)

      from_entries = entries.filter_map(&:course).find { |course| catalog.any? { |own| own.id == course.id } }
      return from_entries if from_entries
      return catalog.first if catalog.one?

      @selected_course
    end

    def payload_for(course, entries, imported)
      tempos = entries.map(&:period).uniq.sort
      subject_name = course&.name.presence || "Componente curricular"
      {
        ok: true,
        warning: nil,
        message: [
          imported&.dig(:message),
          "Encontrei #{tempos.size} tempo(s) de #{subject_name} para #{@classroom.name}."
        ].compact.join(" "),
        classroom_id: @classroom.id,
        course_id: course&.id,
        course_name: subject_name,
        theme: "Aula de #{subject_name}",
        objective: "Compreender e aplicar os conteúdos de #{subject_name} com a turma #{@classroom.name}, nos tempos previstos no horário escolar.",
        content: content_for(subject_name, entries),
        methodology: "Exposição dialogada, registro no quadro e resolução de situações-problema, conforme o plano da disciplina.",
        siage_period: Siage.period_for_date(@lesson_date),
        siage_class_mode: "Aula",
        siage_class_type: "Avulso",
        siage_time_slot: entries.first.time_slot_label,
        weekday: @lesson_date.cwday,
        slots: entries.map { |entry|
          {
            period: entry.period,
            time_slot: entry.time_slot_label,
            subject: entry.course&.name || subject_name
          }
        }
      }
    end

    def content_for(subject_name, entries)
      lines = entries.map do |entry|
        "#{entry.time_slot_label} — #{entry.course&.name || subject_name}"
      end
      "Conteúdos de #{subject_name} de acordo com o horário escolar.\n#{lines.join("\n")}"
    end
  end
end
