class SiageShipment < ApplicationRecord
  KINDS = %w[lesson attendance grades classroom_lessons].freeze
  STATUSES = %w[pending exported verified already_registered partial launched failed].freeze

  belongs_to :professor
  belongs_to :classroom
  belongs_to :lesson, optional: true

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :newest, -> { order(exported_at: :desc, created_at: :desc) }

  def self.record!(professor:, classroom:, kind:, lesson: nil, filename: nil, bimester: nil, status: "exported")
    shipment = existing_for(
      professor: professor,
      classroom: classroom,
      lesson: lesson,
      kind: kind,
      bimester: bimester
    )
    if shipment
      shipment.update!(
        classroom: classroom,
        kind: kind,
        filename: filename,
        bimester: bimester,
        exported_at: Time.current,
        status: next_status_for(shipment.status, status)
      )
      return shipment
    end

    create!(
      professor: professor,
      classroom: classroom,
      lesson: lesson,
      kind: kind,
      status: status,
      filename: filename,
      bimester: bimester,
      exported_at: Time.current
    )
  end

  def self.existing_for(professor:, classroom:, lesson:, kind:, bimester:)
    if lesson
      return where(professor: professor, lesson: lesson).newest.first
    end

    if kind.to_s == "grades" && bimester.present?
      return where(professor: professor, classroom: classroom, kind: "grades", bimester: bimester).newest.first
    end

    nil
  end

  def self.next_status_for(current, incoming)
    incoming = incoming.to_s
    current = current.to_s
    return current if incoming == "exported" && current.in?(%w[verified already_registered launched partial])

    incoming
  end

  def status_label
    {
      "pending" => "Pendente",
      "exported" => "Na fila",
      "verified" => "Conferido",
      "already_registered" => "Já no SIAGE",
      "partial" => "Parcial",
      "launched" => "Lançado",
      "failed" => "Falhou"
    }.fetch(status, status)
  end
end
