module Siage
  class PayloadBuilder
    def self.for_lesson(lesson)
      new(lesson.professor, classroom: lesson.classroom, date: lesson.lesson_date, lesson: lesson).payload
    end

    def self.for_attendance(professor:, classroom:, date:)
      new(professor, classroom: classroom, date: date).payload
    end

    def self.for_grades(professor:, classroom:, bimester: 3, origin: nil)
      new(professor, classroom: classroom, bimester: bimester, origin: origin, payload_kind: "grades").payload
    end

    def self.for_classroom_lessons(professor:, classroom:)
      new(professor, classroom: classroom, export_all_lessons: true).payload
    end

    def initialize(professor, classroom:, date: nil, lesson: nil, bimester: nil, export_all_lessons: false, origin: nil, payload_kind: nil)
      @professor = professor
      @classroom = classroom
      @date = date
      @lesson = lesson
      @bimester = (1..4).cover?(bimester.to_i) ? bimester.to_i : 3
      @export_all_lessons = export_all_lessons
      @origin = origin.to_s.presence
      @payload_kind = payload_kind
    end

    def payload
      {
        source: "maestro",
        kind: @payload_kind || "lesson",
        siage_host: Siage::HOST,
        origin: @origin,
        bimester: (@payload_kind == "grades" ? bimester : nil),
        exported_at: Time.current.iso8601,
        token: Siage::ExtensionToken.generate(professor),
        classroom: {
          id: classroom.id,
          name: classroom.name
        },
        lesson: lesson_payload,
        lessons: lessons_list_payload,
        attendance: attendance_payload,
        grades: grades_payload,
        warnings: warnings
      }.compact
    end

    private

    attr_reader :professor, :classroom, :date, :lesson, :bimester, :export_all_lessons

    def lesson_payload
      current = lesson || lessons_for_date.first
      return if current.blank? && date.blank?

      lesson_hash(current)
    end

    def lessons_list_payload
      records =
        if export_all_lessons
          professor.lessons.where(classroom: classroom).order(lesson_date: :desc, created_at: :desc)
        elsif lesson
          [lesson]
        else
          []
        end

      Array(records).map { |item| lesson_hash(item) }
    end

    def lesson_hash(current_lesson)
      {
        id: current_lesson&.id,
        date: (current_lesson&.lesson_date || date)&.iso8601,
        date_br: (current_lesson&.lesson_date || date)&.strftime("%d/%m/%Y"),
        period: current_lesson&.siage_period,
        class_mode: current_lesson&.siage_class_mode,
        class_type: current_lesson&.siage_class_type,
        time_slot: current_lesson&.siage_time_slot,
        theme: current_lesson&.theme,
        objective: current_lesson&.objective,
        content: current_lesson&.content,
        methodology: current_lesson&.methodology,
        course_name: current_lesson&.course&.name,
        plan: current_lesson ? Siage::LessonPlanBuilder.for(current_lesson) : nil
      }
    end

    def attendance_payload
      return [] if date.blank?

      enrollments.map do |enrollment|
        record = attendance_records[enrollment.id]
        status = record&.status || "present"

        {
          student_id: enrollment.student_id,
          name: enrollment.student.name,
          name_key: NameKey.for(enrollment.student.name),
          status: status,
          siage_status: siage_status_for(status),
          present: siage_present?(status)
        }
      end
    end

    def grades_payload
      enrollments.map do |enrollment|
        student = enrollment.student
        units = (1..3).map { |number| unit_for(student, number) }

        {
          student_id: student.id,
          name: student.name,
          name_key: NameKey.for(student.name),
          units: units,
          global_recovery: nil,
          period_average: nil
        }
      end
    end

    def unit_for(student, number)
      activity = unit_activities[number - 1]

      return { number: number, score: nil, recovery: nil, activity_title: nil } if activity.blank?

      source = activity.replacing_version_for(student) || activity
      submission = submissions_by_student_and_activity[[student.id, source.id]]
      original = submission&.score
      recovery = recoveries_by_student_and_bimester[[student.id, bimester]]&.score

      recovery_for_unit =
        if source.recovery_eligible? &&
           NumericScore.recorded?(original) &&
           NumericScore.recorded?(recovery) &&
           recovery.to_d > original.to_d
          recovery.to_f
        end

      {
        number: number,
        score: NumericScore.recorded?(original) ? original.to_f : nil,
        recovery: recovery_for_unit,
        activity_title: source.title
      }
    end

    def siage_status_for(status)
      case status.to_s
      when "absent" then "faltou"
      when "justified" then "justificado"
      else "presente"
      end
    end

    def siage_present?(status)
      status.to_s != "absent"
    end

    def average_of(scores)
      return if scores.blank?

      (scores.sum.to_d / scores.size).round(1).to_f
    end

    def enrollments
      @enrollments ||= Enrollment
        .where(professor: professor, classroom: classroom, status: "active")
        .includes(:student)
        .joins(:student)
        .order("students.name")
    end

    def attendance_records
      @attendance_records ||=
        if date.blank?
          {}
        else
          AttendanceRecord
            .where(professor: professor, enrollment: enrollments, attendance_date: date)
            .index_by(&:enrollment_id)
        end
    end

    def lessons_for_date
      return Lesson.none if date.blank?

      professor.lessons.where(classroom: classroom, lesson_date: date).order(:created_at)
    end

    def unit_activities
      @unit_activities ||= scored_bimester_activities.first(3)
    end

    def scored_bimester_activities
      @scored_bimester_activities ||= bimester_activities
        .reject { |activity| activity.adapted? }
        .reject { |activity| desfile_civico?(activity) }
        .select do |activity|
          activity.activity_submissions.any? { |submission| NumericScore.recorded?(submission.score) }
        end
    end

    def desfile_civico?(activity)
      I18n.transliterate(activity.title.to_s)
          .downcase
          .include?("desfile civico")
    end

    def bimester_activities
      @bimester_activities ||= Activity
        .joins(:lesson)
        .where(
          lessons: {
            classroom_id: classroom.id,
            professor_id: professor.id
          },
          bimester: bimester
        )
        .includes(:lesson, :activity_submissions, :activity_recipients, adapted_versions: %i[activity_recipients activity_submissions])
        .order(due_date: :asc, title: :asc)
        .to_a
    end

    def submissions_by_student_and_activity
      @submissions_by_student_and_activity ||= ActivitySubmission
        .where(
          professor: professor,
          student_id: enrollments.map(&:student_id),
          activity_id: bimester_activities.map(&:id)
        )
        .index_by { |item| [item.student_id, item.activity_id] }
    end

    def recoveries_by_student_and_bimester
      @recoveries_by_student_and_bimester ||= RecoveryGrade
        .where(
          professor: professor,
          classroom: classroom,
          student_id: enrollments.map(&:student_id),
          bimester: bimester
        )
        .index_by { |item| [item.student_id, item.bimester] }
    end

    def warnings
      messages = []
      titles = unit_activities.map(&:title)

      if titles.any?
        messages << "Unidades do SIAGE neste arquivo: 1ª #{titles[0]}, 2ª #{titles[1] || '—'}, 3ª #{titles[2] || '—'}."
      end

      skipped = scored_bimester_activities.drop(3)
      if skipped.any?
        messages << "O SIAGE só tem 3 unidades. Não foram enviadas: #{skipped.map(&:title).join(', ')}."
      end

      if lesson.present? && lesson.siage_period.blank?
        messages << "Preencha Período, Modo e Tipo da aula para o SIAGE localizar o registro certo."
      end

      messages
    end
  end
end
