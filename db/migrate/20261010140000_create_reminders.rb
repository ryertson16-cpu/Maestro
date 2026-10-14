class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders do |t|
      t.integer :professor_id, null: false
      t.integer :classroom_id
      t.string :title, null: false
      t.datetime :remind_at, null: false
      t.datetime :fired_at
      t.datetime :undone_at
      t.string :source_text
      t.integer :automation_notice_id
      t.timestamps
    end

    add_index :reminders, [:professor_id, :remind_at]
    add_index :reminders, [:professor_id, :fired_at]
  end
end
