module Activities
  class ExamResult
    PASS = 7

    Reading = Struct.new(
      :student,
      :submission,
      :hits,
      :objective_count,
      :identified,
      keyword_init: true
    )
    ItemStat = Struct.new(
      :item,
      :label,
      :prompt,
      :correct_count,
      :scored_count,
      :rate,
      :wrong_letter,
      keyword_init: true
    )

    def initialize(activity)
      @activity = activity
      @classroom = activity.lesson.classroom
      @assigner = ExamAssigner.new(activity)
    end

    def students
      @students ||= @classroom.students.order(:name).to_a
    end

    def submissions
      @submissions ||= @activity
                       .activity_submissions
                       .with_attached_card_photo
                       .with_attached_marked_photo
                       .includes(:student)
                       .to_a
    end

    def assignments
      @assignments ||= @activity.exam_assignments.index_by(&:student_id)
    end

    def by_student
      @by_student ||= submissions.index_by(&:student_id)
    end

    def objective_items
      @objective_items ||= @activity.activity_questions.order(:position).select(&:objective?)
    end

    def readings
      @readings ||= students.map { |student| reading_for(student) }
    end

    def identified
      readings.select(&:identified)
    end

    def scored
      readings.select { |row| row.submission&.score.present? }
    end

    def average
      list = scored.map { |row| row.submission.score.to_f }
      return 0.0 if list.empty?

      (list.sum / list.size).round(1)
    end

    def pass_count
      scored.count { |row| row.submission.score.to_f >= PASS }
    end

    def pass_percent
      return 0 if students.empty?

      ((pass_count.to_f / students.size) * 100).round
    end

    def high_reading
      scored.max_by { |row| row.submission.score.to_f }
    end

    def low_reading
      scored.min_by { |row| row.submission.score.to_f }
    end

    def item_stats
      @item_stats ||= objective_items.map.with_index(1) do |item, index|
        tallies = Hash.new(0)
        correct = 0
        scored.each do |row|
          value = canonical_for(row.student, item, row.submission)
          next if value.blank?

          tallies[value] += 1
          correct += 1 if value == item.correct_letter.to_s.upcase
        end
        n = scored.size
        wrong = tallies.reject { |letter, _| letter == item.correct_letter.to_s.upcase }.max_by { |_, count| count }
        ItemStat.new(
          item: item,
          label: "Q#{index}",
          prompt: item.prompt.to_s,
          correct_count: correct,
          scored_count: n,
          rate: n.zero? ? 0 : ((correct.to_f / n) * 100).round,
          wrong_letter: wrong&.first
        )
      end
    end

    def hardest
      item_stats.min_by { |stat| [ stat.rate, stat.item.position ] }
    end

    def canonical_for(student, item, submission)
      return if submission.blank?

      mapped = @assigner.map_answers(
        submission.answers,
        assignment: assignments[student.id]
      )
      mapped[item.id.to_s].to_s.upcase.presence
    end

    private

    def reading_for(student)
      submission = by_student[student.id]
      hits = 0
      if submission
        objective_items.each do |item|
          value = canonical_for(student, item, submission)
          hits += 1 if value == item.correct_letter.to_s.upcase
        end
      end

      identified = submission.present? && (
        submission.score.present? ||
        submission.card_photo.attached? ||
        submission.marked_photo.attached?
      )

      Reading.new(
        student: student,
        submission: submission,
        hits: hits,
        objective_count: objective_items.size,
        identified: identified
      )
    end
  end
end
