class AddCpfToProfessors < ActiveRecord::Migration[8.1]
  def change
    add_column :professors, :cpf, :string
    add_index :professors, :cpf, unique: true
  end
end
