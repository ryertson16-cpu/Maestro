module Siage
  class GradeStatus
    def initialize(professor)
      @professor = professor
    end

    def apply(classroom:, bimester:, status:, message: nil)
      return unless SiageShipment::STATUSES.include?(status.to_s)
      return unless classroom && (1..4).cover?(bimester.to_i)
      return unless classroom.professor_id == @professor.id

      note = message.to_s.truncate(180).presence
      shipment = SiageShipment.existing_for(
        professor: @professor,
        classroom: classroom,
        lesson: nil,
        kind: "grades",
        bimester: bimester
      )

      if shipment
        attrs = { status: status }
        attrs[:notes] = note if note
        shipment.update!(attrs)
        shipment
      else
        created = SiageShipment.record!(
          professor: @professor,
          classroom: classroom,
          kind: "grades",
          bimester: bimester,
          status: status
        )
        created.update!(notes: note) if note
        created
      end
    end
  end
end
