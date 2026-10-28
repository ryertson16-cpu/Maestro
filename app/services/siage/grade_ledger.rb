module Siage
  class GradeLedger
    Row = Data.define(:classroom, :bimester, :shipment, :status, :unit_titles)

    def initialize(professor:, classroom: nil)
      @professor = professor
      @classroom = classroom
    end

    def rows
      classrooms = classroom_index
      shipments = shipment_index

      pairs.map do |classroom_id, bimester, titles|
        classroom = classrooms[classroom_id]
        next if classroom.blank?

        shipment = shipments[[classroom_id, bimester]]
        Row.new(
          classroom: classroom,
          bimester: bimester,
          shipment: shipment,
          status: shipment&.status || "pending",
          unit_titles: titles
        )
      end.compact.sort_by { |row| [status_rank(row.status), row.classroom.name.to_s, row.bimester.to_i] }
    end

    private

    def pairs
      @pairs ||= begin
        scored = scored_units
        keys = (scored.keys + shipment_index.keys).uniq
        keys.map do |classroom_id, bimester|
          [classroom_id, bimester, scored[[classroom_id, bimester]] || []]
        end
      end
    end

    def scored_units
      scope = Activity.regular
                      .joins(:lesson, :activity_submissions)
                      .where(lessons: { professor_id: @professor.id })
                      .where.not(activity_submissions: { score: nil })
      scope = scope.where(lessons: { classroom_id: @classroom.id }) if @classroom

      grouped = Hash.new { |hash, key| hash[key] = [] }
      scope.includes(:lesson)
           .order(due_date: :asc, title: :asc)
           .distinct
           .each do |activity|
             next if PayloadBuilder.project?(activity)

             key = [activity.lesson.classroom_id, activity.bimester]
             grouped[key] << activity
           end

      grouped.transform_values { |activities| PayloadBuilder.unit_titles_for(activities) }
    end

    def classroom_index
      ids = pairs.map(&:first)
      @professor.classrooms.where(id: ids).index_by(&:id)
    end

    def shipment_index
      @shipment_index ||= begin
        scope = SiageShipment.where(professor: @professor, kind: "grades")
        scope = scope.where(classroom: @classroom) if @classroom
        scope.includes(:classroom).newest.to_a.uniq { |item| [item.classroom_id, item.bimester] }
             .index_by { |item| [item.classroom_id, item.bimester] }
      end
    end

    def status_rank(status)
      {
        "failed" => 0,
        "pending" => 1,
        "exported" => 2,
        "partial" => 3,
        "launched" => 4
      }.fetch(status, 9)
    end
  end
end
