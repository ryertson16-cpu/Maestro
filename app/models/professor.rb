class Professor < ApplicationRecord
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :omniauthable,
         omniauth_providers: %i[google_oauth2 facebook instagram]

  has_many :identities,
           class_name: "ProfessorIdentity",
           dependent: :destroy

  has_one_attached :profile_photo
  has_one :school, dependent: :destroy

  has_many :courses, dependent: :destroy
  has_many :grade_levels, dependent: :destroy
  has_many :classrooms, dependent: :destroy
  has_many :students, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :attendance_records, dependent: :destroy
  has_many :school_courses, dependent: :destroy
  has_many :school_courses,
           dependent: :destroy
  has_many :lessons,
           dependent: :restrict_with_error

  has_many :activities,
           through: :lessons

  has_many :agent_conversations, dependent: :destroy
  has_many :siage_shipments, dependent: :destroy
  has_many :school_calendar_days, dependent: :destroy
  has_many :timetable_entries, dependent: :destroy
  has_many :council_notes, dependent: :destroy
  has_many :lesson_plan_templates, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :automation_rules, dependent: :destroy
  has_many :automation_notices, dependent: :destroy
  has_many :reminders, dependent: :destroy
  has_one :subscription, dependent: :destroy
  has_many :billing_events, dependent: :nullify

  after_create :start_trial_subscription!

  SEXES = %w[male female].freeze

  validates :name, presence: true
  validates :preferred_name, length: { maximum: 80 }
  validates :sex, inclusion: { in: SEXES }, allow_blank: true
  validates :whatsapp_number,
            uniqueness: { allow_blank: true }

  before_validation :normalize_whatsapp_number
  before_validation :normalize_preferred_name
  before_save :reset_whatsapp_welcome, if: :will_save_change_to_whatsapp_number?

  def greeting_name
    preferred_name.presence || name.to_s.split.first.presence
  end

  def feminine?
    sex == "female"
  end

  def courtesy_role
    feminine? ? "professora" : "professor"
  end

  def self.find_by_whatsapp(incoming)
    where.not(whatsapp_number: [nil, ""]).find do |professor|
      Lira::Phone.match?(professor.whatsapp_number, incoming)
    end
  end

  def lira_conversation_for(channel:, external_id:)
    agent_conversations.find_or_create_by!(
      channel: channel,
      external_id: external_id
    )
  end

  def needs_whatsapp_welcome?
    whatsapp_number.present? && whatsapp_welcome_sent_at.blank?
  end

  def maestro_full_access?
    Billing::Access.allowed?(self)
  end

  def initials
    parts = name.to_s.split
    letters = parts.first(2).map { |part| part[0] }.join
    letters.presence&.upcase || email.to_s.first&.upcase || "P"
  end

  private

  def start_trial_subscription!
    return if subscription.present?

    ends = Billing::Config::TRIAL_DAYS.days.from_now
    create_subscription!(
      status: "trialing",
      plan: "monthly",
      trial_ends_at: ends,
      current_period_end: ends
    )
  end

  def normalize_whatsapp_number
    self.whatsapp_number = Lira::Phone.digits(whatsapp_number).presence
  end

  def normalize_preferred_name
    self.preferred_name = preferred_name.to_s.strip.presence
  end

  def reset_whatsapp_welcome
    self.whatsapp_welcome_sent_at = nil
  end
end
