require "csv"

module Platform
  class DeskController < ApplicationController
    before_action :authenticate_professor!
    before_action :require_platform_operator!

    def show
      desk = Billing::Desk.new
      load_filters
      @summary = desk.summary
      @accounts = desk.accounts(
        segment: @segment,
        status: @status,
        q: @query,
        payment_method: @payment_method
      )
      @due_soon = desk.due_soon
      @recent_events = BillingEvent.order(created_at: :desc).limit(20)
      @asaas_on = Billing::Config.asaas_configured?
      @billing_on = Billing::Config.enforced?
    end

    def account
      @professor = Professor.includes(:subscription, :school, :classrooms, :students).find(params[:id])
      @subscription = @professor.subscription
      @usage = Billing::Desk.new.usage_for(@professor)
      @recent_events = @professor.billing_events.order(created_at: :desc).limit(30)
    end

    def export
      load_filters
      desk = Billing::Desk.new
      professors = desk.accounts(
        segment: @segment,
        status: @status,
        q: @query,
        payment_method: @payment_method
      )
      csv = CSV.generate(headers: true) do |rows|
        rows << [
          "nome", "email", "escola", "plano", "pagamento",
          "vence_em", "ultimo_pagamento", "turmas", "alunos", "ultima_aula", "nota"
        ]
        desk.export_rows(professors).each do |row|
          rows << [
            row[:name],
            row[:email],
            row[:school],
            row[:status],
            row[:payment_method],
            row[:period_end],
            row[:last_payment_at],
            row[:classrooms],
            row[:students],
            row[:last_lesson_on],
            row[:note]
          ]
        end
      end

      send_data csv,
                filename: "maestro-gestao-#{Date.current.iso8601}.csv",
                type: "text/csv; charset=utf-8"
    end

    def update
      professor = Professor.find(params[:professor_id] || params[:id])
      Billing::Desk.new.apply!(
        professor,
        intent: params[:intent],
        actor: current_professor,
        payment_method: params[:payment_method]
      )
      redirect_to platform_desk_path(desk_redirect_filters),
                  notice: "#{professor.greeting_name || professor.email}: #{professor.subscription.label}."
    rescue ArgumentError => error
      redirect_to platform_desk_path, alert: error.message
    end

    def update_note
      professor = Professor.find(params[:id])
      professor.update!(management_note: params[:management_note].to_s.strip.presence)
      redirect_to platform_desk_professor_path(professor), notice: "Nota da conta salva."
    end

    private

    def load_filters
      @segment = params[:segment].to_s.presence
      @status = params[:status].to_s.presence
      @query = params[:q].to_s.strip
      @payment_method = params[:payment_method].to_s.presence
    end

    def desk_redirect_filters
      {
        segment: params[:segment],
        status: params[:status],
        q: params[:q],
        payment_method: params[:payment_method]
      }.compact_blank
    end

    def require_platform_operator!
      return if current_professor.platform_operator?

      head :not_found
    end
  end
end
