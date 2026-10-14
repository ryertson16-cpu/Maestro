class AutomationRule < ApplicationRecord
  KINDS = {
    "morning_call" => {
      title: "Chamada do dia",
      hint: "Avisa se ainda falta chamada nas turmas de hoje.",
      hour: 7,
      minute: 30
    },
    "siage_pending" => {
      title: "SIAGE pendente",
      hint: "Avisa lançamento pendente ou que falhou no livro-razão.",
      hour: 8,
      minute: 0
    },
    "monitoring" => {
      title: "Monitoramento",
      hint: "Avisa alunos em atenção ou cuidado.",
      hour: 12,
      minute: 0
    },
    "weekly_backup" => {
      title: "Backup semanal",
      hint: "Na segunda, lembra de guardar uma cópia do caderno neste PC.",
      hour: 16,
      minute: 0
    }
  }.freeze

  belongs_to :professor

  validates :kind, presence: true, inclusion: { in: KINDS.keys }
  validates :hour, inclusion: { in: 0..23 }
  validates :minute, inclusion: { in: 0..59 }
  validates :kind, uniqueness: { scope: :professor_id }

  scope :enabled, -> { where(enabled: true) }

  def self.ensure_defaults_for!(professor)
    KINDS.each do |kind, meta|
      professor.automation_rules.find_or_create_by!(kind: kind) do |rule|
        rule.hour = meta[:hour]
        rule.minute = meta[:minute]
        rule.enabled = true
      end
    end
  end

  def catalog
    KINDS.fetch(kind)
  end

  def due?(now = Time.current)
    return false unless enabled?
    return false unless time_reached?(now)
    return false if last_run_on == now.to_date
    return false if kind == "weekly_backup" && !now.monday?

    true
  end

  def mark_ran!(now = Time.current)
    update!(last_run_on: now.to_date)
  end

  private

  def time_reached?(now)
    (now.hour * 60) + now.min >= (hour * 60) + minute
  end
end
