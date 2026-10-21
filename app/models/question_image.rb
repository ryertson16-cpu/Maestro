module QuestionImage
  TYPES = %w[image/png image/jpeg image/jpg image/webp image/gif].freeze
  MAX_BYTES = 8.megabytes

  module_function

  def accepts!(attachment, errors)
    return unless attachment&.attached?

    unless attachment.content_type.to_s.in?(TYPES)
      errors.add(:image, "use PNG, JPG, WEBP ou GIF")
    end

    return unless attachment.byte_size.to_i > MAX_BYTES

    errors.add(:image, "precisa ter no máximo 8 MB")
  end
end
