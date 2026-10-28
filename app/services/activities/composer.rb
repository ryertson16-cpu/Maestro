module Activities
  class Composer
    def initialize(activity)
      @activity = activity
    end

    def add(question)
      @activity.ensure_correction_token!
      record = ActivityQuestion.snapshot_from(
        question,
        position: next_position
      )
      record.activity = @activity
      record.save!
      record.copy_image_from(question)
      reset_exam_assignments!
      record
    end

    def remove(item)
      item.destroy!
      resequence!
      reset_exam_assignments!
    end

    def move(item, direction)
      swap_with =
        if direction.to_s == "up"
          items.find { |other| other.position == item.position - 1 }
        else
          items.find { |other| other.position == item.position + 1 }
        end
      return unless swap_with

      ActivityQuestion.transaction do
        other_position = swap_with.position
        item_position = item.position
        parking = items.map(&:position).max.to_i + 10
        swap_with.update!(position: parking)
        item.update!(position: other_position)
        swap_with.update!(position: item_position)
      end
      reset_exam_assignments!
    end

    private

    def items
      @activity.activity_questions.order(:position)
    end

    def reset_exam_assignments!
      @activity.exam_assignments.delete_all
    end

    def next_position
      items.maximum(:position).to_i + 1
    end

    def resequence!
      items.each_with_index do |item, index|
        item.update_column(:position, index + 1) if item.position != index + 1
      end
    end
  end
end
