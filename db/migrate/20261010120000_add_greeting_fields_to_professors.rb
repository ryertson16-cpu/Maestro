class AddGreetingFieldsToProfessors < ActiveRecord::Migration[8.1]
  def change
    add_column :professors, :preferred_name, :string
    add_column :professors, :sex, :string
  end
end
