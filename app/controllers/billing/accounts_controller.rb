module Billing
  class AccountsController < ApplicationController
    before_action :authenticate_professor!

    def show
      @subscription = current_professor.subscription
      @full_access = current_professor.maestro_full_access?
    end

    def create
      subscription = Checkout.new(current_professor).start_monthly!
      notice =
        if Billing::Config.asaas_configured?
          "Assinatura criada. Conclua o PIX para liberar o caderno."
        else
          "Assinatura mensal ativada neste computador (Asaas ainda não configurado)."
        end

      redirect_to assinatura_path, notice: notice
    rescue StandardError => error
      redirect_to assinatura_path, alert: error.message
    end
  end
end
