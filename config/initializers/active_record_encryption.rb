# Garante as chaves também no contexto do ActiveRecord::Encryption, que no
# Rails 8.1 ainda consulta credentials.active_record_encryption.primary_key.
require "digest"

seed = "maestro-2-0-siage-password"
keys = {
  primary_key: Digest::SHA256.hexdigest("#{seed}-primary"),
  deterministic_key: Digest::SHA256.hexdigest("#{seed}-deterministic"),
  key_derivation_salt: Digest::SHA256.hexdigest("#{seed}-salt")
}

config = Rails.application.config.active_record.encryption
config.primary_key = keys[:primary_key]
config.deterministic_key = keys[:deterministic_key]
config.key_derivation_salt = keys[:key_derivation_salt]

ActiveRecord::Encryption.configure(**keys) if defined?(ActiveRecord::Encryption.configure)
