class ActivityTrackersController < ApplicationController
  before_action :authenticate_professor!

  def index
    @classrooms = current_professor.classrooms.order(:name)
    @selected_classroom = selected_classroom

    unless @selected_classroom
      @students = []
      @student = nil
      @pending_activities = []
      return
    end

    @students = Enrollment
      .where(
        professor: current_professor,
        classroom: @selected_classroom,
        status: "active"
      )
      .includes(:student)
      .joins(:student)
      .order("students.name")
      .map(&:student)

    @student = @students.find { |student| student.id == params[:student_id].to_i }

    @pending_activities =
      if @student
        activities_for_classroom
          .where.not(
            id: @student.activity_submissions
              .where.not(submitted_on: nil)
              .select(:activity_id)
          )
          .includes(lesson: :course)
          .order(:due_date, :title)
      else
        []
      end
  end

  private

  def selected_classroom
    return if params[:classroom_id].blank?

    current_professor.classrooms.find_by(id: params[:classroom_id])
  end

  def activities_for_classroom
    Activity
      .joins(:lesson)
      .where(lessons: {
        professor_id: current_professor.id,
        classroom_id: @selected_classroom.id
      })
  end
end