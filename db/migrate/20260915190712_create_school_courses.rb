class CreateSchoolCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :school_courses do |t|
      t.references :professor, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :school_courses, [:professor_id, :name], unique: true
  end
end
