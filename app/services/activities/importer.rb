require "json"

module Activities
  class Importer
    Result = Struct.new(:imported, :skipped, :errors, keyword_init: true)

    def initialize(professor:, raw:, classroom: nil)
      @professor = professor
      @raw = raw.to_s
      @classroom = classroom
      @lessons = Lessons::Importer.new(professor: professor, raw: "{}", classroom: classroom)
    end

    def call
      entries = parse_entries
      unless entries
        return Result.new(imported: 0, skipped: 0, errors: [ "Este pacote não é de atividade do Maestro." ])
      end

      imported = 0
      skipped = 0
      errors = []

      entries.each_with_index do |entry, index|
        status = import_entry(entry)
        case status
        when :imported then imported += 1
        when :skipped then skipped += 1
        else
          errors << "Atividade #{index + 1}: #{status}"
        end
      end

      Result.new(imported: imported, skipped: skipped, errors: errors)
    rescue JSON::ParserError
      Result.new(imported: 0, skipped: 0, errors: [ "Não consegui ler o pacote. Cole o JSON copiado no outro caderno." ])
    end

    private

    def parse_entries
      text = @raw.to_s.sub(/\A\uFEFF/, "").strip
      return if text.blank?

      data = JSON.parse(text)
      return unless data.is_a?(Hash)

      if data["format"] == Packager::FORMAT || data["activities"].is_a?(Array)
        return Array(data["activities"])
      end

      if data["format"] == Lessons::Packager::FORMAT || data["lessons"].is_a?(Array)
        return Array(data["lessons"]).select { |item| item.is_a?(Hash) && item["activity"].present? }
      end

      nil
    end

    def import_entry(entry)
      activity_entry = entry["activity"]
      return "falta a atividade no pacote." if activity_entry.blank?
      return "falta o título da atividade." if activity_entry["title"].to_s.strip.blank?

      classroom = @classroom || @lessons.packed_classroom(entry["classroom"])
      return "não achei nem criei a turma." if classroom.blank?

      return :skipped if already_imported?(classroom, activity_entry)

      Lesson.transaction do
        lesson = find_or_build_lesson(entry, classroom, activity_entry)
        lesson.update!(has_activity: true) unless lesson.has_activity?
        @lessons.attach_packed_activity(lesson, activity_entry)
      end
      :imported
    rescue Date::Error
      "data da aula ou do prazo inválida."
    rescue ActiveRecord::RecordInvalid => error
      error.record.errors.full_messages.to_sentence
    end

    def already_imported?(classroom, activity_entry)
      title = activity_entry["title"].to_s.strip
      due = begin
        Date.iso8601(activity_entry["due_date"].to_s)
      rescue Date::Error
        nil
      end

      scope = Activity.joins(:lesson).where(
        adapted: false,
        title: title,
        lessons: {
          professor_id: @professor.id,
          classroom_id: classroom.id
        }
      )
      scope = scope.where(due_date: due) if due
      scope.exists?
    end

    def find_or_build_lesson(entry, classroom, activity_entry)
      date = begin
        Date.iso8601(entry["lesson_date"].to_s)
      rescue Date::Error
        Date.iso8601(activity_entry["due_date"].to_s)
      rescue Date::Error
        Date.current
      end

      theme = entry["theme"].to_s.strip.presence || activity_entry["title"].to_s.strip
      course = @lessons.packed_course(entry["course"])
      lesson = @professor.lessons.find_by(
        classroom: classroom,
        lesson_date: date,
        theme: theme
      )

      if lesson.present? && lesson.activity.present? && lesson.activity.title != activity_entry["title"].to_s.strip
        theme = activity_entry["title"].to_s.strip
        lesson = @professor.lessons.find_by(
          classroom: classroom,
          lesson_date: date,
          theme: theme
        )
      end

      return lesson if lesson.present?

      @professor.lessons.create!(
        classroom: classroom,
        course: course,
        lesson_date: date,
        theme: theme,
        content: entry["content"],
        objective: entry["objective"],
        methodology: entry["methodology"],
        skills: entry["skills"],
        has_activity: true,
        siage_period: entry["siage_period"],
        siage_class_mode: entry["siage_class_mode"],
        siage_class_type: entry["siage_class_type"].presence || "Avulso",
        siage_time_slot: entry["siage_time_slot"].to_s.presence
      )
    end
  end
end
