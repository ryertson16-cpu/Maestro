module Activities
  class AnswerCardIntake
    ScanResult = Struct.new(:launched, :pending, :skipped, keyword_init: true)

    def initialize(activity, professor:, vision: nil)
      @activity = activity
      @professor = professor
      @vision = vision
      @classroom = activity.lesson.classroom
    end

    def ingest!(uploads)
      launched = 0
      pending = 0
      skipped = 0

      Array(uploads).each do |upload|
        next unless upload.respond_to?(:original_filename)

        outcome = ingest_one(upload)
        case outcome
        when :launched then launched += 1
        when :skipped then skipped += 1
        else pending += 1
        end
      end

      ScanResult.new(launched: launched, pending: pending, skipped: skipped)
    end

    PhoneScan = Struct.new(:status, :score, :answers, keyword_init: true)

    def scan_for_student!(upload, student:, overwrite: true)
      return PhoneScan.new(status: :missing_photo) unless upload.respond_to?(:original_filename)
      return PhoneScan.new(status: :lira_off) unless @vision || Lira.llm_enabled?

      path = persist_temp(upload)
      scan = read_card(path)
      answers = scan&.answers || {}
      filled = scan&.filled_count.to_i
      mapped = answers_for_grader(answers, student: student)

      if confident?(filled) && !mixed_exam?
        result = apply!(
          ActivityPendingCard.new(answers: answers),
          student: student,
          overwrite: overwrite,
          photo_path: path,
          scan: scan
        )
        score = ActivitySubmission.find_by(activity: @activity, student: student)&.score
        return PhoneScan.new(status: result, score: score, answers: mapped)
      end

      status = filled.positive? ? :review : :empty
      PhoneScan.new(status: status, answers: mapped)
    ensure
      File.delete(path) if path && File.exist?(path)
    end

    def apply!(card, student: card.student, overwrite: false, photo_path: nil, scan: nil)
      return :missing_student if student.blank?
      return :already_scored if !overwrite && already_scored?(student)

      answers = answers_for_grader(card.answers, student: student)
      assignment = @activity.exam_assignments.find_by(student: student)
      score = Activities::Grader.new(@activity, assignment: assignment).score(answers)
      submission = ActivitySubmission.find_or_initialize_by(activity: @activity, student: student)
      submission.professor = @professor
      submission.answers = answers
      submission.score = score
      submission.submitted_on ||= Date.current
      submission.save!
      stamp_photos!(
        submission,
        student: student,
        path: photo_path,
        scan: scan,
        card: card
      )
      card.destroy! if card.persisted?
      :launched
    end

    private

    def ingest_one(upload)
      path = persist_temp(upload)
      scan = read_card(path)
      answers = scan&.answers || {}
      filled = scan&.filled_count.to_i
      suggested = scan&.name
      student = match_student(suggested)

      return :skipped if student && already_scored?(student)

      if student && confident?(filled)
        result = apply!(
          ActivityPendingCard.new(answers: answers),
          student: student,
          photo_path: path,
          scan: scan
        )
        return :launched if result == :launched
      end

      store_pending(upload, path, answers, filled, suggested, student)
      :pending
    ensure
      File.delete(path) if path && File.exist?(path)
    end

    def read_card(path)
      return @vision.call(path) if @vision

      Activities::AnswerCardVision.scan(path, question_count: card_number_count)
    end

    def persist_temp(upload)
      ext = File.extname(upload.original_filename.to_s).presence || ".bin"
      file = Tempfile.new(["exam-card", ext])
      file.binmode
      upload.rewind if upload.respond_to?(:rewind)
      file.write(upload.read)
      file.flush
      file.close
      upload.rewind if upload.respond_to?(:rewind)
      file.path
    end

    def match_student(name)
      Lessons::NameMatcher.match_student(name, @classroom.students.to_a)
    end

    def already_scored?(student)
      submission = ActivitySubmission.find_by(activity: @activity, student: student)
      NumericScore.recorded?(submission&.score)
    end

    def confident?(filled)
      needed = [1, (objective_count / 2.0).ceil].max
      filled >= needed
    end

    def store_pending(upload, path, answers, filled, suggested, student)
      card = @activity.pending_cards.create!(
        student: student,
        filename: upload.original_filename.to_s.presence || "cartao",
        suggested_name: suggested,
        answers: answers,
        filled_count: filled
      )
      File.open(path, "rb") do |io|
        card.card.attach(
          io: io,
          filename: card.filename,
          content_type: upload.content_type.presence || "application/octet-stream"
        )
      end
      card
    end

    def stamp_photos!(submission, student:, path:, scan:, card:)
      overlay = nil
      source = path.to_s
      if source.blank? || !File.file?(source)
        source = blob_to_temp(card)
      end
      return if source.blank? || !File.file?(source)

      File.open(source, "rb") do |io|
        submission.card_photo.attach(
          io: io,
          filename: "cartao-#{student.id}.png",
          content_type: "image/png"
        )
      end

      marks = CardMark.marks(
        activity: @activity,
        student: student,
        position_answers: scan&.answers || card.answers,
        bubbles: scan&.bubbles
      )
      overlay = CardMarkOverlay.render(source, marks)
      return unless overlay

      File.open(overlay.path, "rb") do |io|
        submission.marked_photo.attach(
          io: io,
          filename: "cartao-marcado-#{student.id}.png",
          content_type: "image/png"
        )
      end
    ensure
      overlay&.close
      overlay&.unlink
      if source.present? && source != path.to_s && source.start_with?(Dir.tmpdir)
        File.delete(source) if File.exist?(source)
      end
    end

    def blob_to_temp(card)
      return unless card.respond_to?(:card) && card.card&.attached?

      file = Tempfile.new(["cartao", ".png"])
      file.binmode
      file.write(card.card.download)
      file.flush
      file.close
      file.path
    rescue StandardError
      nil
    end

    def answers_for_grader(position_map, student: nil)
      mapped = {}
      raw = (position_map || {}).stringify_keys
      rows = Activities::ExamAssigner.new(@activity).presented_for(student)
      rows = @activity.activity_questions.order(:position).map.with_index { |item, index|
        Activities::ExamAssigner::Presented.new(number: index + 1, item: item, pairs: item.choice_pairs, printed_correct: item.correct_letter, choice_map: {})
      } if rows.blank?

      rows.each do |row|
        next unless row.item.objective?

        letter = raw[row.number.to_s]
        mapped[row.item.id.to_s] = letter if letter.present?
      end
      mapped
    end

    def objective_count
      @objective_count ||= @activity.activity_questions.reload.count(&:objective?)
    end

    def card_number_count
      [ @activity.activity_questions.count, 1 ].max
    end

    def mixed_exam?
      @activity.activity_questions.any?(&:discursive?)
    end
  end
end
