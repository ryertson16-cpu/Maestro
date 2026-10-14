module Council
  class NoteBuilder
    def initialize(professor:, classroom:, student:, bimester:)
      @professor = professor
      @classroom = classroom
      @student = student
      @bimester = bimester
    end

    def body
      parts = [
        "#{@student.name} foi acompanhado(a) na turma #{@classroom.name} no #{@bimester}º bimestre.",
        attendance_line,
        grades_line,
        activities_line,
        trajectory_line
      ].compact

      parts << "O parecer pode ser ajustado pelo professor antes do conselho de classe."
      parts.join(" ")
    end

    private

    def attendance_line
      enrollment = Enrollment.find_by(
        professor: @professor,
        classroom: @classroom,
        student: @student,
        status: "active"
      )
      return "Não há frequência lançada neste período." if enrollment.blank?

      start_day, end_day, = Siage.window_for_bimester(@bimester)
      records = AttendanceRecord.where(professor: @professor, enrollment: enrollment)
      records = records.where(attendance_date: start_day..end_day) if start_day && end_day
      return "Não há frequência lançada neste período." if records.empty?

      absences = records.count { |record| record.status == "absent" }
      lates = records.count { |record| record.status == "late" }
      percentage = ((records.size - absences).to_f / records.size * 100).round(1)
      line = "A frequência ficou em #{percentage}%, com #{absences} falta(s)."
      line += " Houve #{lates} registro(s) de atraso, que não contam como falta." if lates.positive?
      line
    end

    def grades_line
      closing = Bimester::ClosingReport.new(
        professor: @professor,
        classroom: @classroom,
        bimester: @bimester
      )
      score = closing.score_for(@student)
      minimum = (closing.setting.minimum_score || 6).to_d
      return "Ainda não há média lançada neste bimestre." unless NumericScore.recorded?(score)

      if score >= minimum
        "A média bimestral foi #{format('%.1f', score)}, acima do mínimo #{format('%.1f', minimum)}."
      else
        "A média bimestral foi #{format('%.1f', score)}, abaixo do mínimo #{format('%.1f', minimum)}, em recuperação."
      end
    end

    def activities_line
      activities = @classroom.activities_for_bimester(@bimester).map(&:activity).compact
      pending = activities.count do |activity|
        activity.due_date.present? &&
          activity.due_date <= Date.current &&
          ActivitySubmission.find_by(professor: @professor, activity: activity, student: @student).blank?
      end
      return if pending.zero?

      "Restam #{pending} atividade(s) sem entrega."
    end

    def trajectory_line
      enrollment = Enrollment.find_by(
        professor: @professor,
        classroom: @classroom,
        student: @student,
        status: "active"
      )
      return if enrollment.blank?

      month = Date.current.beginning_of_month
      records = AttendanceRecord.where(
        professor: @professor,
        enrollment: enrollment,
        attendance_date: month.all_month
      )
      alert = Monitoring::Trajectory.call(records: records, month: month)
      return if alert.blank?

      alert[:reason]
    end
  end
end
