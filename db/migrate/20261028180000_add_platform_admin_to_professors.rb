class AddPlatformAdminToProfessors < ActiveRecord::Migration[8.1]
  def change
    add_column :professors, :platform_admin, :boolean, null: false, default: false
  end
end
