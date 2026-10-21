class AddWhatsappToAutomations < ActiveRecord::Migration[8.1]
  def change
    add_column :automation_rules, :whatsapp, :boolean, null: false, default: true
    add_column :automation_notices, :whatsapp_sent_at, :datetime
  end
end
