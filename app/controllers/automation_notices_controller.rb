class AutomationNoticesController < ApplicationController
  before_action :authenticate_professor!

  def index
    @notices = current_professor.automation_notices.newest
  end

  def show
    notice = current_professor.automation_notices.find(params[:id])
    notice.mark_read!
    redirect_to notice.url.presence || root_path
  end

  def mark_all_read
    current_professor.automation_notices.unread.find_each(&:mark_read!)
    redirect_back fallback_location: automation_notices_path, notice: "Avisos marcados como lidos."
  end
end
