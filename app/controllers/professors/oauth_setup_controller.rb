module Professors
  class OauthSetupController < ApplicationController
    def create
      kind = Oauth::Settings.label_for(params[:provider])
      redirect_to new_professor_session_path,
                  alert: I18n.t("devise.omniauth_callbacks.unconfigured", kind: kind)
    end
  end
end
