module Billing
  class Desk
    INTENTS = %w[complimentary trial activate past_due cancel].freeze

    def initialize(scope: Professor.all)
      @scope = scope
    end

    def summary
      subs = Subscription.where(professor_id: @scope.select(:id))
      {
        professors: @scope.count,
        full_access: @scope.count { |professor| professor.maestro_full_access? },
        trialing: subs.where(status: "trialing").count,
        active: subs.where(status: "active").count,
        complimentary: subs.where(status: "complimentary").count,
        past_due: subs.where(status: "past_due").count,
        canceled: subs.where(status: "canceled").count,
        new_week: @scope.where("professors.created_at >= ?", 7.days.ago).count,
        monthly_estimate: subs.where(status: "active", plan: "monthly").count * Config::MONTHLY_PRICE
      }
    end

    def accounts(status: nil, q: nil)
      professors = @scope.includes(:subscription, :school, :classrooms, :students).order(created_at: :desc)
      if status.present? && Subscription::STATUSES.include?(status)
        professors = professors.joins(:subscription).where(subscriptions: { status: status })
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

    def apply!(professor, intent:, actor:)
      raise ArgumentError, "Ação inválida." unless INTENTS.include?(intent.to_s)

      subscription = professor.subscription || professor.build_subscription
      public_send(:"apply_#{intent}!", subscription)
      subscription.save!

      BillingEvent.create!(
        professor: professor,
        provider: "maestro",
        event_type: "desk.#{intent}",
        payload: { actor_id: actor.id, actor_email: actor.email }
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

    def apply_activate!(subscription)
      subscription.assign_attributes(
        status: "active",
        plan: "monthly",
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
  end
end
