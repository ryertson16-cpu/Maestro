module Professors
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    def google_oauth2
      connect
    end

    def facebook
      connect
    end

    def instagram
      connect
    end

    def failure
      redirect_to after_omniauth_failure_path_for(:professor),
                  alert: I18n.t(
                    "devise.omniauth_callbacks.failure",
                    kind: Oauth::Settings.label_for(failed_strategy_name),
                    reason: failure_message.presence || "autorização recusada"
                  )
    end

    private

    def connect
      outcome = Oauth::Connect.new(request.env["omniauth.auth"], current_professor: current_professor_or_nil).call

      unless outcome.ok?
        redirect_to omniauth_failure_redirect, alert: connect_error_message(outcome.error)
        return
      end

      if professor_signed_in?
        redirect_to settings_path(anchor: "contas-sociais"),
                    notice: I18n.t("devise.omniauth_callbacks.linked", kind: kind_label)
        return
      end

      session[:maestro_login_alerts] = true
      sign_in_and_redirect outcome.professor, event: :authentication
      set_flash_message(:notice, :success, kind: kind_label) if is_navigational_format?
    end

    def current_professor_or_nil
      professor_signed_in? ? current_professor : nil
    end

    def omniauth_failure_redirect
      professor_signed_in? ? settings_path(anchor: "contas-sociais") : new_professor_session_path
    end

    def kind_label
      Oauth::Settings.label_for(request.env.dig("omniauth.auth", "provider") || action_name)
    end

    def failed_strategy_name
      failed_strategy&.name || params[:strategy]
    end

    def connect_error_message(error)
      case error
      when :taken
        I18n.t("devise.omniauth_callbacks.taken", kind: kind_label)
      when :missing_email
        I18n.t("devise.omniauth_callbacks.missing_email", kind: kind_label)
      else
        I18n.t("devise.omniauth_callbacks.failure", kind: kind_label, reason: "dados incompletos")
      end
    end
  end
end
