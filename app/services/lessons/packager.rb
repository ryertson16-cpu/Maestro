require "base64"
require "json"

module Lessons
  class Packager
    FORMAT = "maestro.lesson.pack"
    VERSION = 1

    def initialize(lessons:)
      @lessons = Array(lessons)
    end

    def as_json(*)
      {
        "format" => FORMAT,
        "version" => VERSION,
        "exported_at" => Time.current.iso8601,
        "lessons" => @lessons.map { |lesson| dump_lesson(lesson) }
      }
    end

    def to_pretty_json
      JSON.pretty_generate(as_json)
    end

    def packed_activity_entry(activity)
      dump_lesson(activity.lesson)
        .except("attendance", "siage_shipment", "professor_id")
        .merge("activity" => dump_activity(activity))
    end

    private

    def dump_lesson(lesson)
      classroom = lesson.classroom
      course = lesson.course
      activity = lesson.activity

      {
        "lesson_date" => lesson.lesson_date&.iso8601,
        "theme" => lesson.theme,
        "content" => lesson.content,
        "objective" => lesson.objective,
        "methodology" => lesson.methodology,
        "skills" => lesson.skills,
        "has_activity" => lesson.has_activity?,
        "professor_id" => lesson.professor_id,
        "siage_period" => lesson.siage_period,
        "siage_class_mode" => lesson.siage_class_mode,
        "siage_class_type" => lesson.siage_class_type,
        "siage_time_slot" => lesson.siage_time_slot,
        "siage_shipment" => dump_siage_shipment(lesson),
        "classroom" => {
          "name" => classroom&.name,
          "grade_level" => classroom&.grade_level&.name,
          "school_year" => classroom&.school_year,
          "shift" => classroom&.shift
        }.compact,
        "course" => course && {
          "name" => course.name,
          "knowledge_area" => course.knowledge_area
        },
        "attendance" => dump_attendance(lesson),
        "activity" => activity && dump_activity(activity)
      }
    end

    def dump_siage_shipment(lesson)
      shipment = if lesson.association(:siage_shipments).loaded?
        lesson.siage_shipments.select { |item| item.professor_id == lesson.professor_id }
              .max_by { |item| [ item.exported_at.to_i, item.created_at.to_i ] }
      else
        lesson.siage_shipments.where(professor_id: lesson.professor_id).newest.first
      end

      {
        "status" => shipment&.status.presence || "pending",
        "kind" => shipment&.kind.presence || "lesson"
      }
    end

    def dump_attendance(lesson)
      lesson.attendance_records.filter_map do |record|
        name = record.student&.name.to_s.strip
        next if name.blank?

        {
          "student_name" => name,
          "status" => record.status,
          "notes" => record.notes
        }.compact
      end
    end

    def dump_activity(activity)
      {
        "title" => activity.title,
        "activity_type" => activity.activity_type,
        "maximum_score" => activity.maximum_score,
        "due_date" => activity.due_date&.iso8601,
        "description" => activity.description,
        "instructions" => activity.instructions,
        "bimester" => activity.bimester,
        "weight" => activity.weight,
        "questions" => activity.activity_questions.sort_by(&:position).map { |item| dump_question(item) },
        "submissions" => dump_submissions(activity),
        "exam_assignments" => dump_exam_assignments(activity),
        "adapted" => activity.adapted_versions.map { |item| dump_adapted(item) }
      }
    end

    def dump_adapted(activity)
      dump_activity(activity).merge(
        "adaptation_kind" => activity.adaptation_kind,
        "grade_mode" => activity.grade_mode,
        "recipients" => activity.recipient_students.map { |student| student.name.to_s.strip }.reject(&:blank?)
      )
    end

    def dump_submissions(activity)
      activity.activity_submissions.filter_map do |item|
        name = item.student&.name.to_s.strip
        next if name.blank?

        {
          "student_name" => name,
          "score" => item.score,
          "answers" => item.answers,
          "submitted_on" => item.submitted_on&.iso8601,
          "card_photo" => dump_attachment(item, :card_photo),
          "marked_photo" => dump_attachment(item, :marked_photo)
        }.compact
      end
    end

    def dump_exam_assignments(activity)
      activity.exam_assignments.filter_map do |item|
        name = item.student&.name.to_s.strip
        next if name.blank?

        {
          "student_name" => name,
          "slot" => item.slot,
          "item_order" => item.item_order,
          "choice_maps" => item.choice_maps
        }.compact
      end
    end

    def dump_question(item)
      {
        "position" => item.position,
        "prompt" => item.prompt,
        "kind" => item.kind,
        "choices" => item.choices,
        "correct_letter" => item.correct_letter,
        "points" => item.points,
        "bncc_skill" => item.bncc_skill,
        "image" => dump_attachment(item, :image)
      }.compact
    end

    def dump_attachment(record, name)
      attachment = record.public_send(name)
      return unless attachment&.attached?

      blob = attachment.blob
      return if blob.byte_size.to_i > 2.megabytes

      {
        "filename" => blob.filename.to_s,
        "content_type" => blob.content_type,
        "data" => Base64.strict_encode64(attachment.download)
      }
    rescue StandardError
      nil
    end
  end
end
