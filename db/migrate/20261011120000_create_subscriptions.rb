class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def up
    create_table :subscriptions do |t|
      t.references :professor, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: "trialing"
      t.string :plan, null: false, default: "monthly"
      t.datetime :trial_ends_at
      t.datetime :current_period_end
      t.datetime :last_payment_at
      t.string :asaas_customer_id
      t.string :asaas_subscription_id
      t.string :asaas_checkout_url
      t.timestamps
    end

    add_index :subscriptions, :asaas_customer_id
    add_index :subscriptions, :asaas_subscription_id

    create_table :billing_events do |t|
      t.references :professor, foreign_key: true
      t.string :provider, null: false, default: "asaas"
      t.string :event_type, null: false
      t.string :external_id
      t.json :payload
      t.timestamps
    end

    add_index :billing_events, :external_id

    now = Time.current
    say_with_time "assinatura cortesia para contas já existentes" do
      execute(<<~SQL)
        INSERT INTO subscriptions (
          professor_id, status, plan, current_period_end, created_at, updated_at
        )
        SELECT id, 'complimentary', 'complimentary', NULL, '#{now.to_fs(:db)}', '#{now.to_fs(:db)}'
        FROM professors
        WHERE id NOT IN (SELECT professor_id FROM subscriptions)
      SQL
    end
  end

  def down
    drop_table :billing_events
    drop_table :subscriptions
  end
end
