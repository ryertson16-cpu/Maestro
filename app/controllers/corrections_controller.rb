class CorrectionsController < ApplicationController
  before_action :authenticate_professor!

  def index
    @token = params[:t].to_s.strip.presence
    return if @token.blank?

    activity = current_professor.activities.find_by(correction_token: @token)
    if activity
      redirect_to gabarito_path(activity.correction_token)
    else
      flash.now[:alert] = "QR Code não encontrado neste caderno."
    end
  end
end
