class CreateGradeLevels < ActiveRecord::Migration[8.1]
  def change
    create_table :grade_levels do |t|
      t.references :professor, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
