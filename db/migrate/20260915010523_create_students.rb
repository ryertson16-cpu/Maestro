class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.references :professor, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email
      t.date :birth_date
      t.string :registration_number
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
