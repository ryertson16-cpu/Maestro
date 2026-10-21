module Enem
  class ClassroomResolver
    def initialize(student:, preferred: nil)
      @student = student
      @preferred = preferred
    end

    def classroom
      rooms = classrooms
      return if rooms.empty?
      return @preferred if @preferred && rooms.any? { |room| room.id == @preferred.id }
      return rooms.first if rooms.one?

      rooms.min_by { |room| room.name.to_s }
    end

    def classrooms
      enrollments = Array(@student&.enrollments)
      active = enrollments.select(&:active_in_classroom?)
      (active.presence || enrollments).map(&:classroom).compact.uniq
    end
  end
end
