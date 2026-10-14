require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Maestro20
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Senha do SIAGE (encrypts :siage_password). Sem isso o Rails 8.1 exige
    # active_record_encryption no credentials.yml.enc.
    require "digest"
    encryption_seed = "maestro-2-0-siage-password"
    config.active_record.encryption.primary_key = Digest::SHA256.hexdigest("#{encryption_seed}-primary")
    config.active_record.encryption.deterministic_key = Digest::SHA256.hexdigest("#{encryption_seed}-deterministic")
    config.active_record.encryption.key_derivation_salt = Digest::SHA256.hexdigest("#{encryption_seed}-salt")

    config.time_zone = "Brasilia"
    config.active_record.default_timezone = :local

    config.i18n.default_locale = :"pt-BR"

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
