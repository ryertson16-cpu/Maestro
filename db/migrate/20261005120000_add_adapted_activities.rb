class AddAdaptedActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :adapted, :boolean, default: false, null: false
    add_column :activities, :parent_activity_id, :integer
    add_column :activities, :adaptation_kind, :string
    add_column :activities, :grade_mode, :string

    add_index :activities, :adapted
    add_index :activities, :parent_activity_id
    add_foreign_key :activities, :activities, column: :parent_activity_id

    create_table :activity_recipients do |t|
      t.integer :activity_id, null: false
      t.integer :student_id, null: false
      t.timestamps
    end

    add_index :activity_recipients, %i[activity_id student_id], unique: true
    add_index :activity_recipients, :activity_id
    add_index :activity_recipients, :student_id
    add_foreign_key :activity_recipients, :activities
    add_foreign_key :activity_recipients, :students
  end
end
