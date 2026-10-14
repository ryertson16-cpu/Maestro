module Oauth
  class Connect
    Result = Struct.new(:professor, :error, keyword_init: true) do
      def ok?
        professor.present? && error.blank?
      end
    end

    def initialize(auth, current_professor: nil)
      @auth = auth
      @current_professor = current_professor
    end

    def call
      return Result.new(error: :invalid) if provider.blank? || uid.blank?

      identity = ProfessorIdentity.find_by(provider: provider, uid: uid)
      if identity
        return Result.new(error: :taken) if linking_conflict?(identity.professor)

        return Result.new(professor: identity.professor)
      end

      professor = resolve_professor
      return Result.new(error: :taken) if linking_conflict?(professor)
      return Result.new(error: :missing_email) if professor.blank?

      owned = professor.identities.find_by(provider: provider)
      if owned
        return Result.new(error: :taken) if owned.uid != uid

        return Result.new(professor: professor)
      end

      attach_identity!(professor)
      Result.new(professor: professor)
    end

    private

    def resolve_professor
      return @current_professor if @current_professor.present?
      return existing_by_email if existing_by_email
      return if email.blank?

      create_professor!
    end

    def existing_by_email
      return if email.blank? || !email_trusted?

      @existing_by_email ||= Professor.find_by("LOWER(email) = ?", email.downcase)
    end

    def linking_conflict?(professor)
      @current_professor.present? && professor.present? && professor.id != @current_professor.id
    end

    def create_professor!
      Professor.create!(
        email: email,
        name: name,
        password: Devise.friendly_token[0, 20]
      )
    end

    def attach_identity!(professor)
      professor.identities.create!(
        provider: provider,
        uid: uid,
        email: email,
        name: name
      )

      if professor.name.blank? && name.present?
        professor.update!(name: name)
      end
    end

    def provider
      @auth&.provider.to_s
    end

    def uid
      @auth&.uid.to_s
    end

    def email
      @auth&.info&.email.to_s.strip.downcase.presence
    end

    def name
      raw = @auth&.info
      raw&.name.presence || raw&.nickname.presence || "Professor"
    end

    def email_trusted?
      return false if email.blank?
      return true unless provider == "google_oauth2"

      verified = @auth&.extra&.raw_info&.[]("email_verified")
      verified.nil? || ActiveModel::Type::Boolean.new.cast(verified)
    end
  end
end
