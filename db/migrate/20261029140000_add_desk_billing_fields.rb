class AddDeskBillingFields < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :payment_method, :string
    add_column :professors, :management_note, :text
  end
end
