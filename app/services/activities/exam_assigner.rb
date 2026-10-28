module Activities
  class ExamAssigner
    Presented = Struct.new(
      :number,
      :item,
      :pairs,
      :printed_correct,
      :choice_map,
      keyword_init: true
    )

    DEFAULT_SLOTS = 3

    def initialize(activity)
      @activity = activity
    end

    def ensure!(students)
      roster = Array(students)
      items = catalog
      return ActivityExamAssignment.none if items.empty? || roster.empty?

      if stale?(roster, items)
        @activity.exam_assignments.delete_all
      end
      existing = @activity.exam_assignments.includes(:student).to_a
      return existing if existing.size == roster.size

      packs = build_packs(slot_count(roster.size), items)
      roster.sort_by { |student| [ student.name.to_s, student.id ] }.each_with_index do |student, index|
        pack = packs[index % packs.size]
        @activity.exam_assignments.create!(
          student: student,
          slot: pack[:slot],
          item_order: pack[:item_order],
          choice_maps: pack[:choice_maps]
        )
      end
      @activity.exam_assignments.includes(:student).to_a
    end

    def presented_for(student)
      assignment = student && @activity.exam_assignments.find_by(student: student)
      present(assignment)
    end

    def present(assignment)
      items_by_id = catalog.index_by(&:id)
      order = Array(assignment&.item_order).map(&:to_i)
      order = catalog.map(&:id) if order.blank?
      maps = (assignment&.choice_maps || {}).stringify_keys

      order.filter_map.with_index do |item_id, index|
        item = items_by_id[item_id]
        next unless item

        map = (maps[item_id.to_s] || {}).stringify_keys
        Presented.new(
          number: index + 1,
          item: item,
          pairs: printed_pairs(item, map),
          printed_correct: printed_correct(item, map),
          choice_map: map
        )
      end
    end

    def map_answers(answers, assignment:)
      answers = stringify(answers)
      maps = (assignment&.choice_maps || {}).stringify_keys
      answers.each_with_object({}) do |(item_id, printed), memo|
        map = maps[item_id.to_s] || {}
        memo[item_id] = map[printed.to_s.upcase].presence || printed
      end
    end

    private

    def catalog
      @catalog ||= @activity.activity_questions.with_attached_image.to_a
    end

    def stale?(roster, items)
      current_ids = items.map(&:id).sort
      assigned = @activity.exam_assignments.to_a
      return true if assigned.map(&:student_id).sort != roster.map(&:id).sort

      assigned.any? { |row| Array(row.item_order).map(&:to_i).sort != current_ids }
    end

    def slot_count(student_count)
      [ [ student_count, DEFAULT_SLOTS ].min, 1 ].max
    end

    def build_packs(count, items)
      (1..count).map { |slot| pack_for(slot, items) }
    end

    def pack_for(slot, items)
      rng = Random.new((@activity.id.to_i * 8_191) + slot)
      ordered = items.shuffle(random: rng)
      maps = {}
      ordered.each do |item|
        next unless item.objective?

        originals = item.choice_pairs.map(&:first).compact
        shuffled = originals.shuffle(random: rng)
        maps[item.id.to_s] = shuffled.each_with_index.to_h do |original, index|
          [ Question::LETTERS.fetch(index), original ]
        end
      end
      {
        slot: slot,
        item_order: ordered.map(&:id),
        choice_maps: maps
      }
    end

    def printed_pairs(item, map)
      return [] unless item.objective?

      texts = item.choice_pairs.to_h { |letter, text| [ letter.to_s, text ] }
      if map.blank?
        return item.choice_pairs
      end

      map.sort_by { |printed, _original| printed }.map do |printed, original|
        [ printed, texts[original.to_s] ]
      end.select { |_letter, text| text.to_s.strip.present? }
    end

    def printed_correct(item, map)
      return unless item.objective?

      if map.blank?
        return item.correct_letter
      end

      pair = map.find { |_printed, original| original.to_s.upcase == item.correct_letter.to_s.upcase }
      pair&.first
    end

    def stringify(answers)
      (answers || {}).each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = value
      end
    end
  end
end
