class DashboardController < ApplicationController
  before_action :authenticate_professor!

  def index
    @today = Maestro::TodayBriefing.new(professor: current_professor)
    @monitoring_alert_count = @today.monitoring_alert_count
    @siage_pending_count = @today.siage_pending_count
    @school_setup_pending = current_professor.school.blank? || !current_professor.school.crest.attached?
    @active_projects_count = @today.active_projects_count
    @overdue_projects_count = @today.overdue_projects_count
    @current_classroom = remembered_classroom
  end
end
