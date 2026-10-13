class CreateClassrooms < ActiveRecord::Migration[8.1]
  def change
    create_table :classrooms do |t|
      t.references :professor, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.references :grade_level, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :school_year, null: false
      t.string :shift
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
