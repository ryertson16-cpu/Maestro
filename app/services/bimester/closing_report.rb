module Bimester
  class ClosingReport
    Item = Data.define(:kind, :severity, :label, :detail, :path)

    def initialize(professor:, classroom:, bimester:)
      @professor = professor
      @classroom = classroom
      @bimester = bimester
    end

    def setting
      @setting ||= @classroom.bimester_setting_for(@bimester)
    end

    def items
      @items ||= [
        *missing_grade_items,
        *recovery_items,
        *attendance_items,
        *siage_items,
        *pending_activity_items
      ]
    end

    def blocking?
      items.any? { |item| item.severity == :danger }
    end

    def summary
      {
        danger: items.count { |item| item.severity == :danger },
        warning: items.count { |item| item.severity == :warning },
        closed: setting.closed?
      }
    end

    def score_for(student)
      final_score_for(student)
    end

    def window
      Siage.window_for_bimester(@bimester)
    end

    private

    def students
      @students ||= Enrollment
                    .where(professor: @professor, classroom: @classroom, status: "active")
                    .includes(:student)
                    .joins(:student)
                    .order("students.name")
                    .map(&:student)
    end

    def activities
      @activities ||= @classroom.activities_for_bimester(@bimester).map(&:activity).compact
    end

    def missing_grade_items
      students.filter_map do |student|
        next if student_has_average?(student)

        Item.new(
          :grades,
          :danger,
          student.name,
          "Sem média neste bimestre.",
          "/grades?classroom_id=#{@classroom.id}&bimester=#{@bimester}"
        )
      end
    end

    def recovery_items
      minimum = (setting.minimum_score || 6).to_d
      students.filter_map do |student|
        score = final_score_for(student)
        next unless NumericScore.recorded?(score)
        next unless score < minimum

        Item.new(
          :recovery,
          :warning,
          student.name,
          "Média #{format('%.1f', score)} abaixo de #{format('%.1f', minimum)}.",
          "/grades?classroom_id=#{@classroom.id}&bimester=#{@bimester}"
        )
      end
    end

    def attendance_items
      start_day, end_day, = window
      range = start_day..end_day if start_day && end_day

      students.filter_map do |student|
        enrollment = Enrollment.find_by(professor: @professor, classroom: @classroom, student: student, status: "active")
        next if enrollment.blank?

        records = AttendanceRecord.where(professor: @professor, enrollment: enrollment)
        records = records.where(attendance_date: range) if range
        next if records.empty?

        absences = records.count { |record| record.status == "absent" }
        percentage = ((records.size - absences).to_f / records.size * 100).round(1)
        next unless percentage < 75

        Item.new(
          :attendance,
          :danger,
          student.name,
          "Frequência #{percentage}% no período.",
          "/attendance_records?classroom_id=#{@classroom.id}"
        )
      end
    end

    def siage_items
      start_day, end_day, = window
      lessons = @professor.lessons.where(classroom: @classroom)
      lessons = lessons.where(lesson_date: start_day..end_day) if start_day && end_day
      ledger = Siage::Ledger.new(professor: @professor, classroom: @classroom)
      pending = ledger.rows.select { |row| row.status == "pending" && lessons.map(&:id).include?(row.lesson.id) }

      pending.map do |row|
        Item.new(
          :siage,
          :warning,
          row.classroom.name,
          "Aula de #{I18n.l(row.lesson.lesson_date)} ainda não conferida no SIAGE.",
          "/siage/livro"
        )
      end
    end

    def pending_activity_items
      due = activities.select { |activity| activity.due_date.present? && activity.due_date <= Date.current }
      return [] if due.empty?

      students.filter_map do |student|
        missing = due.count do |activity|
          ActivitySubmission.find_by(professor: @professor, activity: activity, student: student).blank?
        end
        next unless missing.positive?

        Item.new(
          :activities,
          :warning,
          student.name,
          "#{missing} atividade(s) sem entrega.",
          "/grade_levels?classroom_id=#{@classroom.id}"
        )
      end
    end

    def student_has_average?(student)
      NumericScore.recorded?(average_for(student))
    end

    def average_for(student)
      recovery = RecoveryGrade.find_by(professor: @professor, classroom: @classroom, student: student, bimester: @bimester)
      grades = activities.filter_map do |activity|
        submission = activity.activity_submissions.find { |item| item.student_id == student.id }
        score = submission&.score
        next unless NumericScore.recorded?(score)

        score.to_d * activity.weight.to_d
      end
      weight = activities.sum do |activity|
        submission = activity.activity_submissions.find { |item| item.student_id == student.id }
        NumericScore.recorded?(submission&.score) ? activity.weight.to_d : 0
      end
      return nil if weight.zero?

      (grades.sum / weight).round(2)
    end

    def final_score_for(student)
      recovery = RecoveryGrade.find_by(professor: @professor, classroom: @classroom, student: student, bimester: @bimester)
      NumericScore.round_final([average_for(student), recovery&.score&.to_d].compact.max)
    end
  end
end
