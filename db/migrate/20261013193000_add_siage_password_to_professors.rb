class AddSiagePasswordToProfessors < ActiveRecord::Migration[8.1]
  def change
    add_column :professors, :siage_password, :text
  end
end
