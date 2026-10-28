class ApplicationController < ActionController::Base
  include CurrentClassroom

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern, unless: -> {
    controller_path == "public_corrections" || Rails.env.development?
  }

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :load_login_pending_toasts
  before_action :tick_local_automations
  before_action :tick_due_reminders
  before_action :require_maestro_subscription

  helper_method :automation_unread_count, :automation_header_notices, :platform_operator?

  private

  def tick_local_automations
    return unless professor_signed_in?
    return unless request.get? && request.format.html?
    return if devise_controller?
    return unless automation_tables_ready?

    stamped = session[:automation_tick].to_s
    if stamped.present?
      parsed = Time.zone.parse(stamped)
      return if parsed.present? && parsed > 12.minutes.ago
    end

    session[:automation_tick] = Time.current.iso8601
    Maestro::RunAutomationsJob.perform_later(current_professor.id)
  end

  def automation_unread_count
    return 0 unless professor_signed_in?
    return 0 unless automation_tables_ready?

    @automation_unread_count ||= current_professor.automation_notices.unread.count
  end

  def automation_header_notices
    return AutomationNotice.none unless professor_signed_in?
    return AutomationNotice.none unless automation_tables_ready?

    @automation_header_notices ||= current_professor.automation_notices.newest.limit(8)
  end

  def automation_tables_ready?
    return @automation_tables_ready if defined?(@automation_tables_ready)

    @automation_tables_ready = ActiveRecord::Base.connection.data_source_exists?("automation_notices")
  end

  def platform_operator?
    professor_signed_in? && current_professor.platform_operator?
  end

  def require_maestro_subscription
    return unless professor_signed_in?
    return if devise_controller?
    return if controller_path == "billing/accounts"
    return if controller_path == "marketing"
    return if controller_path == "platform/desk"
    return if current_professor.maestro_full_access?

    redirect_to assinatura_path,
                alert: "Para usar o Maestro em sua forma plena, mantenha a assinatura em dia."
  end

  def load_login_pending_toasts
    @login_pending_toasts = []
    return unless professor_signed_in?
    return unless session[:maestro_login_alerts]
    return unless request.format.html?

    @login_pending_toasts = Maestro::LoginAlerts.new(current_professor).toasts
    @login_pending_toasts << Maestro::LoginGreeting.new(current_professor).toast
    session.delete(:maestro_login_alerts)
  end

  def tick_due_reminders
    return unless professor_signed_in?
    return unless request.get? && request.format.html?
    return if devise_controller?
    return unless reminder_tables_ready?

    @login_pending_toasts ||= []
    fired = Maestro::ReminderFiring.new(current_professor).call
    fired.each do |reminder|
      card = Maestro::ReminderCard.new(reminder).as_json
      @login_pending_toasts << {
        kind: "maestro",
        title: "Lembrete",
        message: "#{card[:title]} · #{card[:time_label]}",
        duration: 8000
      }
    end
  end

  def reminder_tables_ready?
    return @reminder_tables_ready if defined?(@reminder_tables_ready)

    @reminder_tables_ready = ActiveRecord::Base.connection.data_source_exists?("reminders")
  end
end
