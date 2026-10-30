module Billing
  class Desk
    INTENTS = %w[complimentary trial activate past_due cancel].freeze
    SEGMENTS = %w[client trial complimentary past_due canceled due_soon].freeze

    def initialize(scope: Professor.all)
      @scope = scope
    end

    def summary
      subs = Subscription.where(professor_id: @scope.select(:id))
      {
        professors: @scope.count,
        clients: subs.where(status: "active").count,
        full_access: @scope.count { |professor| professor.maestro_full_access? },
        trialing: subs.where(status: "trialing").count,
        active: subs.where(status: "active").count,
        complimentary: subs.where(status: "complimentary").count,
        past_due: subs.where(status: "past_due").count,
        canceled: subs.where(status: "canceled").count,
        new_week: @scope.where("professors.created_at >= ?", 7.days.ago).count,
        pix: subs.where(status: "active", payment_method: "pix").count,
        credit_card: subs.where(status: "active", payment_method: "credit_card").count,
        due_soon: due_soon_scope.count,
        monthly_estimate: subs.where(status: "active", plan: "monthly").count * Config::MONTHLY_PRICE
      }
    end

    def accounts(segment: nil, status: nil, q: nil, payment_method: nil)
      professors = @scope.includes(:subscription, :school, :classrooms, :students).order(created_at: :desc)
      professors = apply_segment(professors, segment, status)
      if payment_method.present? && Payment::METHODS.key?(payment_method)
        professors = professors.left_joins(:subscription).where(subscriptions: { payment_method: payment_method })
      end
      if q.present?
        token = "%#{ActiveRecord::Base.sanitize_sql_like(q.strip)}%"
        professors = professors.left_joins(:school).where(
          "professors.name LIKE :q OR professors.email LIKE :q OR schools.name LIKE :q",
          q: token
        )
      end
      professors
    end

    def due_soon
      due_soon_scope.includes(:subscription, :school).order("subscriptions.current_period_end")
    end

    def apply!(professor, intent:, actor:, payment_method: nil)
      raise ArgumentError, "A conta do gestor não entra em período de teste nem em cobrança." if professor.platform_operator?
      raise ArgumentError, "Ação inválida." unless INTENTS.include?(intent.to_s)

      subscription = professor.subscription || professor.build_subscription
      if intent.to_s == "activate"
        apply_activate!(subscription, payment_method: payment_method)
      else
        public_send(:"apply_#{intent}!", subscription)
      end
      subscription.save!

      BillingEvent.create!(
        professor: professor,
        provider: "maestro",
        event_type: "desk.#{intent}",
        payload: {
          actor_id: actor.id,
          actor_email: actor.email,
          payment_method: subscription.payment_method
        }
      )

      subscription
    end

    def apply_complimentary!(subscription)
      subscription.assign_attributes(
        status: "complimentary",
        plan: "complimentary",
        trial_ends_at: nil,
        current_period_end: nil,
        asaas_checkout_url: nil
      )
    end

    def apply_trial!(subscription)
      ends = Config::TRIAL_DAYS.days.from_now
      subscription.assign_attributes(
        status: "trialing",
        plan: "monthly",
        trial_ends_at: ends,
        current_period_end: ends,
        asaas_checkout_url: nil
      )
    end

    def apply_activate!(subscription, payment_method: nil)
      method = Payment.normalize(payment_method) || subscription.payment_method || "pix"
      raise ArgumentError, "Informe PIX ou cartão." unless Payment::METHODS.key?(method)

      subscription.assign_attributes(
        status: "active",
        plan: "monthly",
        payment_method: method,
        last_payment_at: Time.current,
        current_period_end: 1.month.from_now,
        asaas_checkout_url: nil
      )
    end

    def apply_past_due!(subscription)
      subscription.assign_attributes(
        status: "past_due",
        current_period_end: Time.current
      )
    end

    def apply_cancel!(subscription)
      subscription.assign_attributes(
        status: "canceled",
        current_period_end: Time.current,
        asaas_checkout_url: nil
      )
    end

    def export_rows(professors)
      professors.map { |professor| export_row(professor) }
    end

    def usage_for(professor)
      {
        classrooms: professor.classrooms.size,
        students: professor.students.size,
        last_lesson_on: professor.lessons.maximum(:lesson_date),
        provas: professor.activities.where("activities.activity_type LIKE ?", "%Prova%").count,
        siage: professor.cpf.present? || professor.siage_password.present?,
        whatsapp: professor.whatsapp_number.presence
      }
    end

    private

    def apply_segment(professors, segment, status)
      case segment.to_s
      when "client"
        professors.left_joins(:subscription).where(subscriptions: { status: "active" })
      when "trial"
        professors.left_joins(:subscription).where(subscriptions: { status: "trialing" })
      when "complimentary"
        professors.left_joins(:subscription).where(subscriptions: { status: "complimentary" })
      when "past_due"
        professors.left_joins(:subscription).where(subscriptions: { status: "past_due" })
      when "canceled"
        professors.left_joins(:subscription).where(subscriptions: { status: "canceled" })
      when "due_soon"
        professors.left_joins(:subscription).where(
          subscriptions: { status: %w[active trialing past_due] }
        ).where(
          "subscriptions.current_period_end IS NOT NULL AND subscriptions.current_period_end <= ?",
          7.days.from_now
        )
      else
        if status.present?
          professors.left_joins(:subscription).where(subscriptions: { status: status })
        else
          professors
        end
      end
    end

    def due_soon_scope
      @scope.joins(:subscription).where(
        subscriptions: { status: %w[active trialing past_due] }
      ).where(
        "subscriptions.current_period_end IS NOT NULL AND subscriptions.current_period_end <= ?",
        7.days.from_now
      )
    end

    def export_row(professor)
      subscription = professor.subscription
      usage = usage_for(professor)
      {
        name: professor.name,
        email: professor.email,
        school: professor.school&.name,
        status: subscription&.label,
        payment_method: Payment.label(subscription&.payment_method),
        period_end: subscription&.current_period_end,
        last_payment_at: subscription&.last_payment_at,
        classrooms: usage[:classrooms],
        students: usage[:students],
        last_lesson_on: usage[:last_lesson_on],
        note: professor.management_note
      }
    end
  end
end
