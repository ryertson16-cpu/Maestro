class Subscription < ApplicationRecord
  STATUSES = %w[trialing active past_due canceled complimentary].freeze
  PLANS = %w[monthly annual complimentary].freeze

  belongs_to :professor

  validates :status, inclusion: { in: STATUSES }
  validates :plan, inclusion: { in: PLANS }

  def complimentary?
    status == "complimentary"
  end

  def trialing?
    status == "trialing"
  end

  def active?
    status == "active"
  end

  def past_due?
    status == "past_due"
  end

  def canceled?
    status == "canceled"
  end

  def label
    case status
    when "complimentary" then "Cortesia"
    when "trialing" then "Período de teste"
    when "active" then plan == "annual" ? "Anual" : "Mensal"
    when "past_due" then "Pagamento atrasado"
    when "canceled" then "Encerrada"
    else status
    end
  end
end
