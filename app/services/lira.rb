module Lira
  NAME = "Maestro".freeze
  BRAIN_PROVIDERS = %w[openai gemini].freeze

  module_function

  def greeting
    Scope.greeting
  end

  def whatsapp_welcome_message(professor)
    name = professor.name.to_s.split.first.presence || "professor"

    <<~TEXT.strip
      Olá, #{name}! Eu sou o Maestro.

      Seu WhatsApp está vinculado. Por aqui eu consulto só as suas turmas: frequência, notas, atividades e alertas.

      Envie *ajuda* para ver os comandos, ou *hoje* para o resumo do dia.

      Atraso não é falta. Com o caderno aberto neste computador, eu respondo com os dados reais da sua conta.
    TEXT
  end

  def openai_api_key
    ENV["LIRA_OPENAI_API_KEY"].presence || ENV["OPENAI_API_KEY"].presence
  end

  def openai_url
    ENV["LIRA_OPENAI_URL"].presence || "https://api.openai.com/v1/chat/completions"
  end

  def openai_model
    ENV["LIRA_OPENAI_MODEL"].presence || "gpt-4o-mini"
  end

  def openai_configured?
    openai_api_key.present?
  end

  def gemini_api_key
    ENV["LIRA_GEMINI_API_KEY"].presence || ENV["GEMINI_API_KEY"].presence
  end

  def gemini_url
    ENV["LIRA_GEMINI_URL"].presence ||
      "https://generativelanguage.googleapis.com/v1beta/models/#{gemini_model}:generateContent"
  end

  def gemini_model
    ENV["LIRA_GEMINI_MODEL"].presence || "gemini-2.5-flash"
  end

  def gemini_configured?
    gemini_api_key.present?
  end

  def brain_choice
    ENV["LIRA_BRAIN"].to_s.strip.downcase.presence
  end

  def brain_provider
    chosen = brain_choice
    if BRAIN_PROVIDERS.include?(chosen)
      return :gemini if chosen == "gemini" && gemini_configured?
      return :openai if chosen == "openai" && openai_configured?

      return nil
    end

    return :openai if openai_configured?
    return :gemini if gemini_configured?

    nil
  end

  def llm_enabled?
    brain_provider.present?
  end

  def brain_label
    case brain_provider
    when :openai then "GPT (#{openai_model})"
    when :gemini then "Gemini (#{gemini_model})"
    else "local (comandos e palavras-chave)"
    end
  end

  def whatsapp_token
    ENV["LIRA_WHATSAPP_TOKEN"].presence
  end

  def whatsapp_phone_number_id
    ENV["LIRA_WHATSAPP_PHONE_NUMBER_ID"].presence
  end

  def whatsapp_verify_token
    ENV["LIRA_WHATSAPP_VERIFY_TOKEN"].presence
  end

  def whatsapp_app_secret
    ENV["LIRA_WHATSAPP_APP_SECRET"].presence
  end

  def whatsapp_enabled?
    whatsapp_token.present? && whatsapp_phone_number_id.present?
  end
end
