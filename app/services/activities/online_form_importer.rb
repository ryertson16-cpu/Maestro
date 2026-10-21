module Activities
  class OnlineFormImporter
    CANONICAL_TITLE = "Atividade online"
    ONLINE_FORM_TITLES = [
      CANONICAL_TITLE,
      "Questionário online"
    ].freeze

    def self.existing_activity(professor:, classroom:, title:, lesson_date:)
      date = lesson_date.to_date
      scope = Activity
              .joins(:lesson)
              .includes(:activity_submissions)
              .where(
                lessons: {
                  professor_id: professor.id,
                  classroom_id: classroom.id
                }
              )
              .order("activities.id desc")

      scope.find { |activity|
        same_title?(activity.title, title) &&
          activity.lesson.lesson_date == date
      } || scope.find { |activity|
        same_title?(activity.title, title) &&
          activity.due_date == date
      }
    end

    def self.same_title?(left, right)
      a = Lessons::NameMatcher.normalize(left)
      b = Lessons::NameMatcher.normalize(right)
      return false if a.blank? || b.blank?
      return true if a == b

      online_form_title?(a) && online_form_title?(b)
    end

    def self.online_form_title?(value)
      n = Lessons::NameMatcher.normalize(value)
      ONLINE_FORM_TITLES.any? { |title| Lessons::NameMatcher.normalize(title) == n }
    end

    def initialize(professor:)
      @professor = professor
    end

    def import!(title:, lesson_date:, course_id:, items:)
      grouped = items.group_by { |item| item[:classroom_id] }
      created = []

      Activity.transaction do
        grouped.each do |classroom_id, rows|
          classroom = @professor.classrooms.find(classroom_id)
          activity = self.class.existing_activity(
            professor: @professor,
            classroom: classroom,
            title: title,
            lesson_date: lesson_date
          )
          lesson = activity&.lesson
          added, skipped = apply_rows!(classroom, lesson, activity, rows) if activity

          if activity && added.zero?
            created << { classroom: classroom, lesson: lesson, activity: activity, count: 0, skipped: skipped }
            next
          end

          unless activity
            lesson = build_lesson(classroom, title, lesson_date, course_id)
            lesson.save!
            lesson.activity.save! unless lesson.activity.persisted?
            activity = lesson.activity
            added, skipped = apply_rows!(classroom, lesson, activity, rows)
          end

          created << { classroom: classroom, lesson: lesson, activity: activity, count: added, skipped: skipped }
        end
      end

      created
    end

    private

    def build_lesson(classroom, title, lesson_date, course_id)
      course = @professor.courses.find_by(id: course_id) || classroom.course
      date = lesson_date.to_date

      lesson = @professor.lessons.new(
        classroom: classroom,
        course: course,
        lesson_date: date,
        theme: title,
        has_activity: true,
        siage_time_slot: "1º tempo",
        siage_class_mode: "Aula",
        siage_class_type: "Avulso",
        siage_period: Siage.period_for_date(date)
      )
      lesson.build_activity(
        title: title,
        activity_type: "Questionário",
        due_date: date,
        maximum_score: 10,
        bimester: Siage.bimester_for_date(date),
        weight: 1,
        instructions: "Importada do questionário online. Quem enviou o formulário consta como presente nesta aula."
      )
      lesson
    end

    def apply_rows!(classroom, lesson, activity, rows)
      added = 0
      skipped = 0

      rows.each do |row|
        student = classroom.students.find(row[:student_id])
        submission = ActivitySubmission.find_or_initialize_by(activity: activity, student: student)
        already_scored = NumericScore.recorded?(submission.score)
        delivered = submission.submitted_on.present?

        submission.professor = @professor
        submission.score = row[:score] unless already_scored
        submission.submitted_on ||= submitted_on_for(row, lesson)
        submission.save!

        if already_scored && delivered
          skipped += 1
        else
          added += 1
        end

        enrollment = Enrollment.find_by!(
          professor: @professor,
          student: student,
          classroom: classroom
        )
        attendance = AttendanceRecord.find_or_initialize_by(
          professor: @professor,
          enrollment: enrollment,
          attendance_date: lesson.lesson_date,
          lesson: lesson
        )
        attendance.status = "present"
        attendance.save!
      end

      [added, skipped]
    end

    def submitted_on_for(row, lesson)
      value = row[:submitted_at].presence || lesson.lesson_date
      value.respond_to?(:to_date) ? value.to_date : Date.parse(value.to_s)
    rescue Date::Error, ArgumentError
      lesson.lesson_date
    end
  end
end
