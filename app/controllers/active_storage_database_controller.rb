class ActiveStorageDatabaseController < ActiveStorage::BaseController
  skip_forgery_protection

  def show
    payload = decode(:blob_key)
    return head :not_found if payload.blank?

    data = service_for(payload).download(payload[:key])
    send_data data,
              type: payload[:content_type].presence || "application/octet-stream",
              disposition: payload[:disposition].presence || "inline",
              filename: params[:filename]
  rescue ActiveStorage::FileNotFoundError
    head :not_found
  end

  def update
    payload = decode(:blob_token)
    return head :unprocessable_entity if payload.blank?
    if acceptable_token?(payload)
      service_for(payload).upload payload[:key], request.body, checksum: payload[:checksum]
      head :no_content
    else
      head :unprocessable_entity
    end
  rescue ActiveStorage::IntegrityError
    head :unprocessable_entity
  end

  private

  def decode(purpose)
    ActiveStorage.verifier.verified(params[:encoded_key], purpose: purpose)
  end

  def service_for(payload)
    ActiveStorage::Blob.services.fetch(payload[:service_name] || Rails.configuration.active_storage.service)
  end

  def acceptable_token?(payload)
    payload[:content_type] == request.content_mime_type &&
      payload[:content_length] == request.content_length &&
      (payload[:checksum].blank? || payload[:checksum] == OpenSSL::Digest::MD5.base64digest(request.raw_post))
  end
end
