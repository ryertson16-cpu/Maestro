module Siage
  class LedgerStatus
    def initialize(professor)
      @professor = professor
    end

    def apply(lesson_ids:, status:, message: nil)
      return 0 unless SiageShipment::STATUSES.include?(status.to_s)

      lessons = @professor.lessons.where(id: Array(lesson_ids).map(&:to_i))
      updated = 0
      lessons.find_each do |lesson|
        upsert(lesson, status, message)
        updated += 1
      end
      updated
    end

    def apply_lesson(lesson, status, message = nil)
      upsert(lesson, status, message)
    end

    private

    def upsert(lesson, status, message)
      shipment = SiageShipment.where(professor: @professor, lesson: lesson).newest.first
      note = message.to_s.truncate(180).presence

      if shipment
        attrs = { status: status }
        attrs[:notes] = note if note
        shipment.update!(attrs)
        shipment
      else
        created = SiageShipment.record!(
          professor: @professor,
          classroom: lesson.classroom,
          lesson: lesson,
          kind: "lesson",
          status: status
        )
        created.update!(notes: note) if note
        created
      end
    end
  end
end
