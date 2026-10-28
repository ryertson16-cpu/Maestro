module Platform
  class DeskController < ApplicationController
    before_action :authenticate_professor!
    before_action :require_platform_operator!

    def show
      desk = Billing::Desk.new
      @summary = desk.summary
      @status = params[:status].to_s.presence
      @query = params[:q].to_s.strip
      @accounts = desk.accounts(status: @status, q: @query)
      @recent_events = BillingEvent.order(created_at: :desc).limit(20)
      @asaas_on = Billing::Config.asaas_configured?
      @billing_on = Billing::Config.enforced?
    end

    def update
      professor = Professor.find(params[:professor_id])
      Billing::Desk.new.apply!(
        professor,
        intent: params[:intent],
        actor: current_professor
      )
      redirect_to platform_desk_path(status: params[:status], q: params[:q]),
                  notice: "#{professor.greeting_name || professor.email}: #{professor.subscription.label}."
    rescue ArgumentError => error
      redirect_to platform_desk_path, alert: error.message
    end

    private

    def require_platform_operator!
      return if current_professor.platform_operator?

      head :not_found
    end
  end
end
