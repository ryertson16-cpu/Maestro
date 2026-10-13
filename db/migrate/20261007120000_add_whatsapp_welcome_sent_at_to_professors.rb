class AddWhatsappWelcomeSentAtToProfessors < ActiveRecord::Migration[8.1]
  def change
    add_column :professors, :whatsapp_welcome_sent_at, :datetime
  end
end
