module Enem
  class GradeImporter
    def initialize(simulado, professor:)
      @simulado = simulado
      @professor = professor
      @builder = Enem::ActivityBuilder.new(simulado)
    end

    def import_sheet!(sheet)
      return :empty unless sheet.ready?
      return :no_classroom if sheet.classroom.blank?

      activity = @builder.ensure_activity!(sheet.classroom)
      sheet.recompute!
      sheet.confirmed = true
      sheet.save!

      submission = ActivitySubmission.find_or_initialize_by(activity: activity, student: sheet.student)
      submission.professor = @professor
      submission.score = sheet.score
      submission.submitted_on ||= @simulado.applied_on
      submission.save!
      :imported
    end

    def import_all!
      counts = { imported: 0, empty: 0, no_classroom: 0 }
      @simulado.sheets.includes(:student, :classroom).order(:id).each do |sheet|
        status = import_sheet!(sheet)
        counts[status] += 1 if counts.key?(status)
      end
      counts
    end
  end
end
