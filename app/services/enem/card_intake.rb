module Enem
  class CardIntake
    MAX_FILES = 80
    MAX_BYTES = 20.megabytes

    def self.uploads_from(params)
      raw = params[:card_pdfs].presence || params["card_pdfs"] || params[:card_pdf]
      if raw.respond_to?(:to_unsafe_h) && !raw.is_a?(Array)
        raw = raw.to_unsafe_h.values
      elsif raw.is_a?(Hash)
        raw = raw.values
      end
      Array.wrap(raw).select { |upload| upload.respond_to?(:tempfile) }
    end

    def initialize(simulado)
      @simulado = simulado
    end

    def call(uploads:, student_id: nil)
      files = self.class.uploads_from({ card_pdfs: uploads })
      files = Array.wrap(uploads).select { |upload| upload.respond_to?(:tempfile) } if files.empty?
      result = Result.new(saved: [], parked: [], errors: [], received: 0)

      if files.empty?
        result.errors << "Envie ao menos um PDF de cartão."
        return result
      end
      if files.size > MAX_FILES
        result.errors << "Envie no máximo #{MAX_FILES} PDFs por vez."
        return result
      end

      explicit = student_for(student_id) if files.one?
      created = []

      files.each do |upload|
        if upload.size.to_i > MAX_BYTES
          result.errors << "#{upload.original_filename}: o PDF deve ter no máximo 20 MB."
          next
        end

        created << park!(upload, nil)
        result.received += 1
      rescue StandardError => error
        Rails.logger.warn("[enem-card] #{error.class}: #{error.message}")
        result.errors << "#{upload.original_filename}: não foi possível guardar o cartão."
      end

      created.each do |pending|
        outcome = identify_pending!(pending, explicit: explicit, vision: false)
        bucket_outcome(result, outcome)
      end

      created.select(&:persisted?).each do |pending|
        Enem::IdentifyCardJob.perform_later(pending.id)
      end

      result
    end

    def identify_pending!(pending, explicit: nil, vision: true)
      return unless pending&.persisted?

      roster = @simulado.students_in_caderno.to_a
      scan = pending.card_pdf.open do |file|
        Enem::CardReader.read(
          file.path,
          filename: pending.filename,
          roster: roster,
          vision: vision
        )
      end

      student = explicit || match_filename(pending.filename, roster) || match_name(scan&.name, roster)
      if student
        sheet = pending.card_pdf.open do |file|
          save_sheet!(
            student,
            path: file.path,
            blob: pending.card_pdf,
            letters: scan&.letters,
            source: scan&.source
          )
        end
        pending.destroy!
        return [:saved, sheet]
      end

      pending.update!(
        suggested_name: scan&.name.presence || pending.suggested_name,
        answers: scan&.letters.presence || pending.answers
      )
      [:parked, pending]
    rescue StandardError => error
      Rails.logger.warn("[enem-card] #{error.class}: #{error.message}")
      [:error, "#{pending.filename}: não foi possível ler o cartão."]
    end

    def assign_pending!(pending, student)
      raise ArgumentError, "aluno" if student.blank?

      letters = Array(pending.answers)
      source = pending.suggested_name.present? ? "lira" : "manual"
      sheet = pending.card_pdf.open do |file|
        if letters.count { |letter| Question::LETTERS.include?(letter.to_s.upcase) } < 1
          scan = Enem::CardReader.read(file.path, filename: pending.filename)
          letters = scan.letters
          source = scan.source
        end
        save_sheet!(student, path: file.path, blob: pending.card_pdf, letters: letters, source: source)
      end
      pending.destroy!
      sheet
    end

    Result = Struct.new(:saved, :parked, :errors, :received, keyword_init: true)

    private

    def bucket_outcome(result, outcome)
      kind, value = outcome
      case kind
      when :saved then result.saved << value
      when :parked then result.parked << value
      when :error then result.errors << value
      end
    end

    def student_for(student_id)
      return if student_id.blank?

      @simulado.students_in_caderno.find_by(id: student_id)
    end

    def match_filename(name, roster)
      stem = File.basename(name.to_s, ".*")
      Lessons::NameMatcher.match_student(stem, roster)
    end

    def match_name(name, roster)
      Lessons::NameMatcher.match_student(name, roster)
    end

    def park!(upload, scan)
      pending = @simulado.pending_cards.create!(
        filename: upload.original_filename.to_s,
        suggested_name: scan&.name,
        answers: scan&.letters || []
      )
      pending.card_pdf.attach(upload)
      pending
    end

    def save_sheet!(student, path:, upload: nil, blob: nil, letters: nil, source: nil)
      parsed_letters = Array(letters)
      if parsed_letters.count { |letter| Question::LETTERS.include?(letter.to_s.upcase) } < 1
        parsed = Enem::KeyParser.from_pdf(path)
        parsed_letters = parsed.letters
        source ||= parsed.source
      end

      sheet = @simulado.sheets.find_or_initialize_by(student: student)
      sheet.classroom = Enem::ClassroomResolver.new(
        student: student,
        preferred: @simulado.classroom
      ).classroom
      sheet.answers = parsed_letters
      sheet.suggestion_source = source.presence || "manual"
      sheet.confirmed = false
      sheet.recompute!
      if upload
        sheet.card_pdf.attach(upload)
      elsif blob&.attached?
        sheet.card_pdf.attach(
          io: StringIO.new(blob.download),
          filename: blob.filename.to_s,
          content_type: blob.content_type
        )
      end
      sheet.save!
      sheet
    end
  end
end
