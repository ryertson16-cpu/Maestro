class BillingEvent < ApplicationRecord
  belongs_to :professor, optional: true

  validates :provider, :event_type, presence: true
end
