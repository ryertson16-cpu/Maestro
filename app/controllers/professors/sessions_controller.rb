module Professors
  class SessionsController < Devise::SessionsController
    def new
      hide_redirect_prompt
      super
    end

    def after_sign_in_path_for(resource)
      session[:maestro_login_alerts] = true
      stored_location_for(resource) || root_path
    end

    private

    def hide_redirect_prompt
      prompts = [
        I18n.t("devise.failure.unauthenticated"),
        I18n.t("devise.failure.professor.unauthenticated")
      ]

      flash.delete(:alert) if prompts.include?(flash[:alert])
    end
  end
end
