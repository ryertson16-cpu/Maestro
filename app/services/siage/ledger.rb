module Siage
  class Ledger
    Window = Data.define(:lesson, :classroom, :shipment, :status)

    def initialize(professor:, classroom: nil)
      @professor = professor
      @classroom = classroom
    end

    def rows
      lessons.map do |lesson|
        shipment = latest_by_lesson[lesson.id]
        Window.new(
          lesson: lesson,
          classroom: lesson.classroom,
          shipment: shipment,
          status: shipment&.status || "pending"
        )
      end.sort_by { |row| [status_rank(row.status), -row.lesson.lesson_date.to_time.to_i] }
    end

    OPEN_STATUSES = %w[pending exported failed].freeze

    def open_lessons
      rows.select { |row| OPEN_STATUSES.include?(row.status) }.map(&:lesson)
    end

    def summary
      grouped = rows.group_by(&:status)
      queued = grouped["exported"]&.size.to_i
      waiting = grouped["pending"]&.size.to_i
      {
        pending: waiting + queued,
        queued: queued,
        exported: queued,
        verified: grouped["verified"]&.size.to_i,
        already_registered: grouped["already_registered"]&.size.to_i,
        failed: grouped["failed"]&.size.to_i,
        total: rows.size
      }
    end

    private

    def lessons
      @lessons ||= begin
        scope = @professor.lessons.includes(:classroom, :course).where("lesson_date >= ?", 120.days.ago)
        scope = scope.where(classroom: @classroom) if @classroom
        scope.order(lesson_date: :desc).to_a
      end
    end

    def latest_by_lesson
      @latest_by_lesson ||= SiageShipment
                            .where(professor: @professor, lesson_id: lessons.map(&:id))
                            .newest
                            .group_by(&:lesson_id)
                            .transform_values(&:first)
    end

    def status_rank(status)
      {
        "failed" => 0,
        "pending" => 1,
        "exported" => 2,
        "already_registered" => 3,
        "verified" => 4
      }.fetch(status, 9)
    end
  end
end
