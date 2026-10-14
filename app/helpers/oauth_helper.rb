module OauthHelper
  OAUTH_BUTTONS = [
    { provider: :google_oauth2, brand: "google", label: "Continuar com Google" },
    { provider: :facebook, brand: "facebook", label: "Continuar com Facebook" },
    { provider: :instagram, brand: "instagram", label: "Continuar com Instagram" }
  ].freeze

  def oauth_authorize_path_for(provider)
    if Devise.omniauth_configs[provider.to_sym]
      public_send(:"professor_#{provider}_omniauth_authorize_path")
    else
      oauth_unconfigured_path(provider: provider)
    end
  end

  def oauth_brand_icon(brand)
    svg =
      case brand.to_s
      when "google"
        <<~SVG
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.76h3.56c2.08-1.92 3.28-4.74 3.28-8.09z"/>
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.56-2.76c-.99.66-2.26 1.06-3.72 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84A10.97 10.97 0 0 0 12 23z"/>
            <path fill="#FBBC05" d="M5.84 14.11A6.59 6.59 0 0 1 5.5 12c0-.73.13-1.45.34-2.11V7.05H2.18A10.97 10.97 0 0 0 1 12c0 1.77.42 3.45 1.18 4.95z"/>
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 8.7 1 5.74 2.94 4.18 5.95l3.66 2.84C8.71 7.31 11.14 5.38 12 5.38z"/>
          </svg>
        SVG
      when "facebook"
        <<~SVG
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path fill="#1877F2" d="M22 12.07C22 6.5 17.52 2 12 2S2 6.5 2 12.07c0 5.02 3.66 9.18 8.44 9.93v-7.03H7.9v-2.9h2.54V9.84c0-2.5 1.49-3.89 3.78-3.89 1.1 0 2.24.2 2.24.2v2.47h-1.26c-1.24 0-1.63.77-1.63 1.56v1.88h2.78l-.44 2.9h-2.34V22c4.78-.75 8.44-4.91 8.44-9.93z"/>
          </svg>
        SVG
      when "instagram"
        <<~SVG
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <defs>
              <linearGradient id="ig" x1="0%" y1="100%" x2="100%" y2="0%">
                <stop offset="0%" stop-color="#F58529"/>
                <stop offset="45%" stop-color="#DD2A7B"/>
                <stop offset="100%" stop-color="#8134AF"/>
              </linearGradient>
            </defs>
            <rect x="3" y="3" width="18" height="18" rx="5" fill="url(#ig)"/>
            <circle cx="12" cy="12" r="4.1" fill="none" stroke="#fff" stroke-width="1.7"/>
            <circle cx="16.7" cy="7.3" r="1" fill="#fff"/>
          </svg>
        SVG
      end

    raw(svg) if svg.present?
  end
end
