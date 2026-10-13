module Professors
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_sign_up_params, only: :create

    def after_sign_up_path_for(_resource)
      session[:maestro_login_alerts] = true
      root_path
    end

    private

    def configure_sign_up_params
      devise_parameter_sanitizer.permit(:sign_up, keys: %i[name])
    end
  end
end
