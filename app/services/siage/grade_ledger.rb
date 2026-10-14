module Siage
  class GradeLedger
    Row = Data.define(:classroom, :bimester, :shipment, :status)

    def initialize(professor:, classroom: nil)
      @professor = professor
      @classroom = classroom
    end

    def rows
      shipments.map do |shipment|
        Row.new(
          classroom: shipment.classroom,
          bimester: shipment.bimester,
          shipment: shipment,
          status: shipment.status
        )
      end.sort_by { |row| [status_rank(row.status), row.classroom.name.to_s, row.bimester.to_i] }
    end

    private

    def shipments
      scope = SiageShipment.where(professor: @professor, kind: "grades")
      scope = scope.where(classroom: @classroom) if @classroom
      scope.includes(:classroom).newest.to_a.uniq { |item| [item.classroom_id, item.bimester] }
    end

    def status_rank(status)
      {
        "failed" => 0,
        "exported" => 1,
        "partial" => 2,
        "launched" => 3
      }.fetch(status, 9)
    end
  end
end
