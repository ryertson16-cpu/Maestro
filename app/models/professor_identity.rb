class ProfessorIdentity < ApplicationRecord
  PROVIDERS = %w[google_oauth2 facebook instagram].freeze

  belongs_to :professor

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  validates :provider, uniqueness: { scope: :professor_id }
end
