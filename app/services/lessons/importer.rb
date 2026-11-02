require "base64"
require "json"
require "stringio"

module Lessons
  class Importer
    Result = Struct.new(:imported, :skipped, :errors, keyword_init: true)

    def initialize(professor:, raw:, classroom: nil)
      @professor = professor
      @raw = raw.to_s
      @classroom = classroom
    end

    def call
      payload = parse_payload
      unless payload
        return Result.new(imported: 0, skipped: 0, errors: [ "Este pacote não é de aula do Maestro." ])
      end

      imported = 0
      skipped = 0
      errors = []

      Array(payload["lessons"]).each_with_index do |entry, index|
        status = import_lesson(entry)
        case status
        when :imported then imported += 1
        when :skipped then skipped += 1
        else
          errors << "Aula #{index + 1}: #{status}"
        end
      end

      Result.new(imported: imported, skipped: skipped, errors: errors)
    rescue JSON::ParserError
      Result.new(imported: 0, skipped: 0, errors: [ "Não consegui ler o pacote. Cole o JSON copiado no outro caderno." ])
    end

    private

    def parse_payload
      text = @raw.to_s.sub(/\A\uFEFF/, "").strip
      return if text.blank?

      data = JSON.parse(text)
      data = { "lessons" => [ data ] } if data.is_a?(Hash) && data["theme"].present? && data["lessons"].blank?
      return unless data.is_a?(Hash)
      return unless data["format"] == Packager::FORMAT || data["lessons"].is_a?(Array)

      data["lessons"] = Array(data["lessons"])
      data
    end

    def import_lesson(entry)
      return "falta o tema da aula." if entry["theme"].blank?

      date = Date.iso8601(entry["lesson_date"].to_s)
      classroom = resolve_classroom(entry["classroom"])
      return "não achei nem criei a turma." if classroom.blank?

      slot = entry["siage_time_slot"].to_s.presence
      already = @professor.lessons.where(
        classroom: classroom,
        lesson_date: date,
        theme: entry["theme"]
      )
      already = already.where(siage_time_slot: slot) if slot.present?
      return :skipped if already.exists?

      Lesson.transaction do
        existing_course = find_existing_course(entry["course"])
        course = existing_course || create_course(entry["course"])
        lesson = @professor.lessons.create!(
          classroom: classroom,
          course: course,
          lesson_date: date,
          theme: entry["theme"],
          content: entry["content"],
          objective: entry["objective"],
          methodology: entry["methodology"],
          skills: entry["skills"],
          has_activity: entry["activity"].present? || entry["has_activity"] == true,
          siage_period: entry["siage_period"],
          siage_class_mode: entry["siage_class_mode"],
          siage_class_type: entry["siage_class_type"].presence || "Avulso",
          siage_time_slot: slot
        )
        import_activity(lesson, entry["activity"]) if entry["activity"].present?
        import_attendance(lesson, entry["attendance"])
        apply_siage_tag(lesson, entry, existing_course: existing_course)
      end
      :imported
    rescue Date::Error
      "data da aula inválida."
    rescue ActiveRecord::RecordInvalid => error
      error.record.errors.full_messages.to_sentence
    end

    def resolve_classroom(meta)
      return @classroom if @classroom

      name = meta.is_a?(Hash) ? meta["name"].to_s.strip : meta.to_s.strip
      return if name.blank?

      year = meta.is_a?(Hash) ? meta["school_year"].to_i : 0
      year = Date.current.year if year < 2000
      found = @professor.classrooms.find_by(name: name, school_year: year)
      found ||= @professor.classrooms.where("LOWER(name) = ?", name.downcase).order(school_year: :desc).first
      return found if found

      grade_name = meta.is_a?(Hash) ? meta["grade_level"].to_s.strip : ""
      grade_name = "Série" if grade_name.blank?
      grade = @professor.grade_levels.find_or_create_by!(name: grade_name)
      attrs = {
        name: name,
        school_year: year,
        grade_level: grade,
        active: true
      }
      shift = meta.is_a?(Hash) ? meta["shift"].to_s : ""
      attrs[:shift] = shift if Classroom::SHIFT_LABELS.key?(shift)
      @professor.classrooms.create!(attrs)
    end

    def find_existing_course(meta)
      return if meta.blank?

      name = meta.is_a?(Hash) ? meta["name"].to_s.strip : meta.to_s.strip
      return if name.blank?

      @professor.courses.where("LOWER(name) = ?", name.downcase).first
    end

    def create_course(meta)
      return if meta.blank?

      name = meta.is_a?(Hash) ? meta["name"].to_s.strip : meta.to_s.strip
      return if name.blank?

      area = meta.is_a?(Hash) ? meta["knowledge_area"].to_s : ""
      area = "matematica" unless Course::KNOWLEDGE_AREAS.key?(area)
      @professor.courses.create!(name: name, knowledge_area: area, active: true)
    end

    def apply_siage_tag(lesson, entry, existing_course:)
      packed = entry["siage_shipment"]
      status = packed.is_a?(Hash) ? packed["status"].to_s : "pending"
      return if status.blank? || status == "pending"
      return unless SiageShipment::STATUSES.include?(status)
      return unless entry["professor_id"].to_i == @professor.id
      return if existing_course.blank?

      Siage::LedgerStatus.new(@professor).apply_lesson(lesson, status)
    end

    def import_activity(lesson, entry, parent: nil)
      return if entry.blank?

      types = Lesson::ACTIVITY_TYPES
      activity_type = entry["activity_type"].to_s
      activity_type = "Lista de exercícios" unless types.include?(activity_type)
      due = begin
        Date.iso8601(entry["due_date"].to_s)
      rescue Date::Error
        lesson.lesson_date
      end
      due = lesson.lesson_date if due < lesson.lesson_date

      attrs = {
        title: entry["title"].presence || lesson.theme,
        activity_type: activity_type,
        maximum_score: entry["maximum_score"].presence || 10,
        due_date: due,
        description: entry["description"],
        instructions: entry["instructions"],
        bimester: coerce_bimester(entry["bimester"], lesson.lesson_date),
        weight: entry["weight"].presence || 1
      }

      if parent
        recipients = matched_students(Array(entry["recipients"]), lesson.classroom)
        return if recipients.empty?

        activity = lesson.activities.build(
          attrs.merge(
            adapted: true,
            parent_activity: parent,
            adaptation_kind: Activity::ADAPTATION_KINDS.key?(entry["adaptation_kind"].to_s) ? entry["adaptation_kind"] : "reduced",
            grade_mode: Activity::GRADE_MODES.key?(entry["grade_mode"].to_s) ? entry["grade_mode"] : "replaces"
          )
        )
        recipients.each { |student| activity.activity_recipients.build(student: student) }
        activity.save!
      else
        activity = lesson.create_activity!(attrs)
      end

      Array(entry["questions"]).each_with_index do |item, index|
        kind = item["kind"].to_s
        kind = "discursive" unless Question::KINDS.key?(kind)
        question = activity.activity_questions.create!(
          position: item["position"].presence || (index + 1),
          prompt: item["prompt"].presence || "Questão #{index + 1}",
          kind: kind,
          choices: item["choices"].presence || [],
          correct_letter: kind == "objective" ? item["correct_letter"].presence || "A" : nil,
          points: item["points"].presence || 1,
          bncc_skill: item["bncc_skill"]
        )
        attach_blob(question.image, item["image"])
      end

      import_submissions(activity, entry["submissions"], lesson.classroom)
      import_exam_assignments(activity, entry["exam_assignments"], lesson.classroom)
      return if parent

      Array(entry["adapted"]).each do |item|
        import_activity(lesson, item, parent: activity)
      end
    end

    def import_attendance(lesson, rows)
      Array(rows).each do |row|
        student = match_student(row["student_name"], lesson.classroom)
        next unless student

        enrollment = enrollment_for(student, lesson.classroom)
        next unless enrollment

        status = row["status"].to_s
        status = "present" unless AttendanceRecord.statuses.key?(status)

        record = lesson.attendance_records.find_or_initialize_by(
          professor: @professor,
          enrollment: enrollment,
          attendance_date: lesson.lesson_date
        )
        record.status = status
        record.notes = row["notes"] if row["notes"].present?
        record.save!
      end
    end

    def import_submissions(activity, rows, classroom)
      Array(rows).each do |row|
        student = match_student(row["student_name"], classroom)
        next unless student
        next unless enrollment_for(student, classroom)

        submitted_on = begin
          Date.iso8601(row["submitted_on"].to_s)
        rescue Date::Error
          nil
        end

        submission = activity.activity_submissions.find_or_initialize_by(
          professor: @professor,
          student: student
        )
        submission.score = row["score"]
        submission.answers = row["answers"].presence || {}
        submission.submitted_on = submitted_on
        submission.save!
        attach_blob(submission.card_photo, row["card_photo"])
        attach_blob(submission.marked_photo, row["marked_photo"])
      end
    end

    def import_exam_assignments(activity, rows, classroom)
      Array(rows).each do |row|
        student = match_student(row["student_name"], classroom)
        next unless student
        next unless enrollment_for(student, classroom)

        assignment = activity.exam_assignments.find_or_initialize_by(student: student)
        assignment.slot = [ row["slot"].to_i, 1 ].max
        assignment.item_order = row["item_order"].presence || []
        assignment.choice_maps = row["choice_maps"].presence || {}
        assignment.save!
      end
    end

    def matched_students(names, classroom)
      Array(names).filter_map { |name| match_student(name, classroom) }.uniq
    end

    def match_student(name, classroom)
      needle = name.to_s.strip
      return if needle.blank?

      NameMatcher.match_student(needle, classroom_students(classroom)) ||
        NameMatcher.match_student(needle, professor_students)
    end

    def classroom_students(classroom)
      @classroom_students ||= {}
      @classroom_students[classroom.id] ||= classroom.students.to_a
    end

    def professor_students
      @professor_students ||= @professor.students.to_a
    end

    def enrollment_for(student, classroom)
      found = classroom.enrollments.find_by(student_id: student.id)
      return found if found
      return unless student.professor_id == @professor.id

      created = classroom.enrollments.create!(
        professor: @professor,
        student: student,
        enrolled_on: Date.current,
        status: "active"
      )
      @classroom_students&.delete(classroom.id)
      created
    end

    def coerce_bimester(value, date)
      number = value.to_i
      return number if (1..4).cover?(number)

      Siage.bimester_for_date(date)
    end

    def attach_blob(attachment, image)
      return if image.blank? || image["data"].blank?

      binary = Base64.decode64(image["data"].to_s)
      return if binary.blank?

      attachment.attach(
        io: StringIO.new(binary),
        filename: image["filename"].presence || "arquivo.png",
        content_type: image["content_type"].presence || "image/png"
      )
    rescue StandardError
      nil
    end
  end
end
