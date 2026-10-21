module Enem
  class IdentifyCardJob < ApplicationJob
    queue_as :default

    def perform(pending_id)
      pending = EnemPendingCard.find_by(id: pending_id)
      return if pending.blank?

      Enem::CardIntake.new(pending.enem_simulado).identify_pending!(pending, vision: true)
    end
  end
end
