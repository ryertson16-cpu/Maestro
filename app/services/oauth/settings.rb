module Oauth
  module Settings
    PROVIDERS = {
      google_oauth2: {
        label: "Google",
        env_id: "GOOGLE_CLIENT_ID",
        env_secret: "GOOGLE_CLIENT_SECRET",
        credential: %i[oauth google],
        options: {
          scope: "email,profile",
          prompt: "select_account",
          access_type: "online"
        }
      },
      facebook: {
        label: "Facebook",
        env_id: "FACEBOOK_APP_ID",
        env_secret: "FACEBOOK_APP_SECRET",
        credential: %i[oauth facebook],
        options: {
          scope: "email",
          info_fields: "name,email",
          image_size: "large"
        }
      },
      instagram: {
        label: "Instagram",
        env_id: "INSTAGRAM_CLIENT_ID",
        env_secret: "INSTAGRAM_CLIENT_SECRET",
        credential: %i[oauth instagram],
        options: {
          scope: "instagram_business_basic"
        }
      }
    }.freeze

    module_function

    def each_configured
      PROVIDERS.each do |key, spec|
        id, secret = credentials_for(spec)
        next if id.blank? || secret.blank?

        yield key, id, secret, spec[:options]
      end
    end

    def configured?(provider)
      spec = PROVIDERS[provider.to_sym]
      return false if spec.blank?

      id, secret = credentials_for(spec)
      id.present? && secret.present?
    end

    def label_for(provider)
      PROVIDERS.dig(provider.to_sym, :label) || provider.to_s.humanize
    end

    def credentials_for(spec)
      if Rails.env.test?
        return [ "test-#{spec[:label].parameterize}-id", "test-secret" ]
      end

      creds = Rails.application.credentials.dig(*spec[:credential]) || {}
      id = ENV[spec[:env_id]].presence || creds[:client_id].presence || creds[:app_id].presence
      secret = ENV[spec[:env_secret]].presence || creds[:client_secret].presence || creds[:app_secret].presence
      [id, secret]
    end
  end
end
