class AddProfileFieldsToProfessors < ActiveRecord::Migration[8.1]
  def change
    add_column :professors, :name, :string
    add_column :professors, :phone, :string
    add_column :professors, :school_name, :string
    add_column :professors, :bio, :text
  end
end
