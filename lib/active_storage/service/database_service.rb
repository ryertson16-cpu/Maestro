require "active_storage/service"
require "openssl"

module ActiveStorage
  class Service::DatabaseService < Service
    def initialize(public: false, **_options)
      @public = public
    end

    def upload(key, io, checksum: nil, **)
      instrument :upload, key: key, checksum: checksum do
        data = io.read.b
        if checksum.present? && OpenSSL::Digest::MD5.base64digest(data) != checksum
          raise ActiveStorage::IntegrityError
        end

        record = ActiveStorageDatum.find_or_initialize_by(key: key)
        record.data = data
        record.save!
      end
    end

    def download(key, &block)
      data = payload_for(key)
      if block_given?
        instrument :streaming_download, key: key do
          yield data
        end
      else
        instrument :download, key: key do
          data
        end
      end
    end

    def download_chunk(key, range)
      instrument :download_chunk, key: key, range: range do
        payload_for(key)[range]
      end
    end

    def delete(key)
      instrument :delete, key: key do
        ActiveStorageDatum.where(key: key).delete_all
      end
    end

    def delete_prefixed(prefix)
      instrument :delete_prefixed, prefix: prefix do
        ActiveStorageDatum.where("key LIKE ?", "#{sanitize_prefix(prefix)}%").delete_all
      end
    end

    def exist?(key)
      instrument :exist, key: key do |payload|
        answer = ActiveStorageDatum.exists?(key: key)
        payload[:exist] = answer
        answer
      end
    end

    def compose(source_keys, destination_key, **)
      data = source_keys.map { |source_key| payload_for(source_key) }.join
      upload(destination_key, StringIO.new(data))
    end

    def url_for_direct_upload(key, expires_in:, content_type:, content_length:, checksum:, custom_metadata: {})
      instrument :url, key: key do |payload|
        token = ActiveStorage.verifier.generate(
          {
            key: key,
            content_type: content_type,
            content_length: content_length,
            checksum: checksum,
            service_name: name
          },
          expires_in: expires_in,
          purpose: :blob_token
        )

        url_helpers.update_rails_database_service_url(token, url_options).tap do |generated_url|
          payload[:url] = generated_url
        end
      end
    end

    def headers_for_direct_upload(_key, content_type:, **)
      { "Content-Type" => content_type }
    end

    private

    def payload_for(key)
      record = ActiveStorageDatum.find_by(key: key)
      raise ActiveStorage::FileNotFoundError if record.blank?

      record.data
    end

    def sanitize_prefix(prefix)
      ActiveRecord::Base.sanitize_sql_like(prefix.to_s)
    end

    def private_url(key, expires_in:, filename:, content_type:, disposition:, **)
      generate_url(key, expires_in: expires_in, filename: filename, content_type: content_type, disposition: disposition)
    end

    def public_url(key, filename:, content_type: nil, disposition: :inline, **)
      generate_url(key, expires_in: nil, filename: filename, content_type: content_type, disposition: disposition)
    end

    def generate_url(key, expires_in:, filename:, content_type:, disposition:)
      content_disposition = content_disposition_with(type: disposition, filename: filename)
      verified_key = ActiveStorage.verifier.generate(
        {
          key: key,
          disposition: content_disposition,
          content_type: content_type,
          service_name: name
        },
        expires_in: expires_in,
        purpose: :blob_key
      )

      if url_options.blank?
        raise ArgumentError, "Cannot generate URL for #{filename} using Database service, please set ActiveStorage::Current.url_options."
      end

      url_helpers.rails_database_service_url(verified_key, filename: filename, **url_options)
    end

    def url_helpers
      @url_helpers ||= Rails.application.routes.url_helpers
    end

    def url_options
      ActiveStorage::Current.url_options
    end
  end
end
