class CorrectionsController < ApplicationController
  include CorrectionHost

  before_action :authenticate_professor!

  def index
    store_correction_host
    @token = params[:t].to_s.strip.presence
    if @token.present?
      activity = current_professor.activities.find_by(correction_token: @token)
      if activity
        redirect_to gabarito_path(activity.correction_token)
        return
      end

      flash.now[:alert] = "QR Code não encontrado neste caderno."
    end

    @classroom = resolve_classroom
    @classrooms = current_professor.classrooms.order(:name)
    @activities = classroom_activities
    @activity = @activities.find_by(id: params[:activity_id]) ||
                @activities.find(&:assembled?) ||
                @activities.first
    @correction_url = gabarito_public_url(@activity) if @activity
  end

  private

  def classroom_activities
    return Activity.none if @classroom.blank?

    Activity
      .regular
      .joins(:lesson)
      .where(lessons: { classroom_id: @classroom.id, professor_id: current_professor.id })
      .includes(:lesson, :activity_questions, :activity_submissions)
      .order(due_date: :desc, created_at: :desc)
  end
end
