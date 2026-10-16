module Grades
  class BimesterScore
    def self.activities_for(classroom, bimester)
      Activity
        .joins(:lesson)
        .where(
          lessons: { classroom_id: classroom.id },
          bimester: bimester
        )
        .includes(
          :activity_submissions,
          :activity_recipients,
          :lesson,
          adapted_versions: %i[activity_recipients activity_submissions]
        )
        .order(due_date: :asc, title: :asc)
    end

    def initialize(student:, activities:, recovery: nil)
      @student = student
      @activities = Array(activities)
      @recovery = recovery
    end

    def average
      weighted_total = 0.to_d
      total_weight = 0.to_d

      @activities.each do |activity|
        next unless activity.counts_toward_average_for?(@student)

        source = activity.replacing_version_for(@student) || activity
        submission = activity.submission_for_average(@student)
        next unless NumericScore.recorded?(submission&.score)
        next if source.weight.blank? || source.weight.to_d <= 0

        weighted_total += submission.score.to_d * source.weight.to_d
        total_weight += source.weight.to_d
      end

      return if total_weight.zero?

      (weighted_total / total_weight).round(2)
    end

    def final_score
      NumericScore.round_final([average, recovery_score].compact.max)
    end

    private

    def recovery_score
      score = @recovery.respond_to?(:score) ? @recovery.score : @recovery
      return unless NumericScore.recorded?(score)

      score.to_d
    end
  end
end
