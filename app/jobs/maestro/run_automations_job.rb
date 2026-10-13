module Maestro
  class RunAutomationsJob < ApplicationJob
    queue_as :default

    def perform(professor_id = nil)
      scope = professor_id.present? ? Professor.where(id: professor_id) : Professor.all
      scope.find_each do |professor|
        Maestro::AutomationRunner.new(professor).call
      end
    end
  end
end
