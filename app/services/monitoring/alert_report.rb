module Monitoring
  class AlertReport
    FILTERS = %w[all danger activities grades attendance].freeze

    attr_reader :professor, :classroom, :month, :filter

    def initialize(professor:, classroom: nil, month: nil, filter: "all")
      @professor = professor
      @classroom = classroom
      @month = month.presence || Date.current.beginning_of_month
      @filter = FILTERS.include?(filter.to_s) ? filter.to_s : "all"
    end

    def classrooms
      @classrooms ||= professor
                      .classrooms
                      .includes(:grade_level)
                      .order(:name)
    end

    def classroom_alert_counts
      @classroom_alert_counts ||= classrooms.each_with_object({}) do |item, counts|
        counts[item.id] = rows_for(item).count(&:alerted?)
      end
    end

    def classroom_alert_breakdown
      classrooms.filter_map do |item|
        alerted = rows_for(item).select(&:alerted?)
        next if alerted.empty?

        {
          classroom: item,
          attention: alerted.count { |row| row.severity == :warning },
          care: alerted.count { |row| row.severity == :danger },
          total: alerted.size
        }
      end
    end

    def total_alert_count
      classroom_alert_counts.values.sum
    end

    def student_rows
      return [] if classroom.blank?

      rows_for(classroom)
    end

    def visible_rows
      student_rows
        .select { |row| row.matches_filter?(filter) }
        .sort_by { |row| [row.severity == :danger ? 0 : 1, row.student.name.to_s] }
    end

    def summary
      alerted = student_rows.select(&:alerted?)

      {
        total: alerted.size,
        danger: alerted.count { |row| row.severity == :danger },
        warning: alerted.count { |row| row.severity == :warning },
        activities: alerted.count { |row| row.pending_activities.any? },
        grades: alerted.count { |row| row.grade_alerts.any? || row.unscored_activities.any? },
        attendance: alerted.count { |row| row.attendance_alert.present? || row.late_alert.present? || row.trajectory_alert.present? }
      }
    end

    def has_alerts?
      summary[:total].positive?
    end

    def month_label
      I18n.l(month, format: "%B de %Y").capitalize
    end

    private

    def rows_for(classroom)
      @rows_by_classroom ||= {}
      @rows_by_classroom[classroom.id] ||= build_student_rows(classroom)
    end

    def build_student_rows(classroom)
      enrollments = Enrollment
                    .where(
                      professor: professor,
                      classroom: classroom,
                      status: "active"
                    )
                    .includes(:student)
                    .joins(:student)
                    .order("students.name")

      return [] if enrollments.empty?

      student_ids = enrollments.map(&:student_id)

      activities = Activity
                   .joins(:lesson)
                   .where(
                     lessons: {
                       professor_id: professor.id,
                       classroom_id: classroom.id
                     }
                   )
                   .includes(
                     :lesson,
                     :activity_submissions,
                     :activity_recipients,
                     adapted_versions: %i[activity_recipients activity_submissions],
                     lesson: :course
                   )
                   .order(
                     "activities.due_date ASC",
                     "activities.title ASC"
                   )

      submissions = ActivitySubmission
                    .where(
                      professor: professor,
                      student_id: student_ids,
                      activity_id: activities.map(&:id)
                    )
                    .index_by do |submission|
                      [submission.student_id, submission.activity_id]
                    end

      recovery_grades = RecoveryGrade
                        .where(
                          professor: professor,
                          classroom: classroom,
                          student_id: student_ids
                        )
                        .index_by do |recovery|
                          [recovery.student_id, recovery.bimester]
                        end

      attendance_records = AttendanceRecord
                           .where(
                             professor: professor,
                             enrollment_id: enrollments.map(&:id),
                             attendance_date: Attendance::Frequency.month_range(month)
                           )
                           .group_by(&:enrollment_id)

      enrollments.map do |enrollment|
        student = enrollment.student

        student_activities = activities.map do |activity|
          {
            activity: activity,
            submission: submissions[[student.id, activity.id]]
          }
        end

        pending_activities = student_activities.select do |item|
          activity = item[:activity]
          submission = item[:submission]

          activity.required_delivery_for?(student) &&
            submission.blank? &&
            activity.due_date.present? &&
            activity.due_date <= Date.current
        end

        unscored_activities = student_activities.select do |item|
          activity = item[:activity]
          submission = item[:submission]

          activity.required_delivery_for?(student) &&
            activity.due_date.present? &&
            activity.due_date <= Date.current &&
            !NumericScore.recorded?(submission&.score)
        end

        attendance_for_student = attendance_records[enrollment.id] || []
        attendance_percentage = attendance_percentage_for(attendance_for_student)

        StudentAlert.new(
          student: student,
          classroom: classroom,
          month: month,
          pending_activities: pending_activities,
          unscored_activities: unscored_activities,
          grade_alerts: build_grade_alerts(
            student: student,
            activities: student_activities,
            recovery_grades: recovery_grades
          ),
          attendance_percentage: attendance_percentage,
          attendance_alert: attendance_alert_for(attendance_percentage),
          late_alert: late_alert_for(attendance_for_student),
          trajectory_alert: Monitoring::Trajectory.call(
            records: attendance_for_student,
            month: month
          )
        )
      end
    end

    def build_grade_alerts(student:, activities:, recovery_grades:)
      activities_by_bimester = activities.group_by do |item|
        item[:activity].bimester.to_i
      end

      activities_by_bimester.filter_map do |bimester, bimester_activities|
        score = Grades::BimesterScore.new(
          student: student,
          activities: bimester_activities.map { |item| item[:activity] },
          recovery: recovery_grades[[student.id, bimester]]
        )
        average = score.average
        next unless NumericScore.recorded?(average)

        final_score = score.final_score

        next unless final_score < 6

        severity = final_score < 4 ? :danger : :warning

        {
          bimester: bimester,
          average: average,
          final_score: final_score,
          severity: severity,
          label: severity == :danger ? "Cuidado, média abaixo de 4" : "Atenção, média entre 4 e 6"
        }
      end
    end

    def attendance_percentage_for(records)
      Attendance::Frequency.percentage(records)
    end

    def attendance_alert_for(percentage)
      return unless Attendance::Frequency.below_minimum?(percentage)

      {
        severity: :danger,
        label: "Cuidado, frequência abaixo de 75%",
        reason: "Frequência abaixo de 75%"
      }
    end

    def late_alert_for(records)
      return nil if records.blank?

      late_count = records.count(&:late?)
      return nil if late_count.zero?
      return nil unless late_count * 2 >= records.size

      {
        severity: :warning,
        label: "Atenção, chegando atrasado",
        reason: "#{late_count} de #{records.size} registros deste mês estão como atraso."
      }
    end

  end
end
