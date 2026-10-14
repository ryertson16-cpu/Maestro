class SettingsController < ApplicationController
  before_action :authenticate_professor!

  def show
    @professor = current_professor
    @school = current_professor.school
    AutomationRule.ensure_defaults_for!(current_professor)
    @automation_rules = current_professor.automation_rules.sort_by { |rule| AutomationRule::KINDS.keys.index(rule.kind) || 99 }
  end

  def update_automations
    params.fetch(:rules, {}).each do |kind, attrs|
      rule = current_professor.automation_rules.find_by(kind: kind)
      next unless rule

      rule.update(
        enabled: ActiveModel::Type::Boolean.new.cast(attrs[:enabled]),
        whatsapp: ActiveModel::Type::Boolean.new.cast(attrs[:whatsapp]),
        hour: attrs[:hour].to_i,
        minute: attrs[:minute].to_i
      )
    end

    redirect_to settings_path(anchor: "automacoes"), notice: "Automações atualizadas."
  end
end
