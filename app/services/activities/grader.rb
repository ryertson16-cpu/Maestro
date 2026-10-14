module Activities
  class Grader
    def initialize(activity)
      @activity = activity
      @items = activity.activity_questions.order(:position)
    end

    def score(answers)
      answers = stringify(answers)
      earned = 0.to_d
      total = @items.sum { |item| item.points.to_d }
      return 0 if total <= 0

      @items.each do |item|
        earned += awarded_points(item, answers[item.id.to_s])
      end

      ceiling = @activity.maximum_score.presence&.to_d || 10.to_d
      raw = (earned / total) * ceiling
      [[raw.round(1), 0].max, 10].min
    end

    def awarded_points(item, value)
      if item.objective?
        return item.points.to_d if value.to_s.upcase == item.correct_letter.to_s.upcase

        return 0.to_d
      end

      points = BigDecimal(value.to_s.tr(",", "."))
      [[points, 0].max, item.points.to_d].min
    rescue ArgumentError
      0.to_d
    end

    private

    def stringify(answers)
      (answers || {}).each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = value
      end
    end
  end
end
