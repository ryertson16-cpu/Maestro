class CreateActivityPendingCards < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_pending_cards do |t|
      t.references :activity, null: false, foreign_key: true
      t.references :student, foreign_key: true
      t.string :filename, null: false
      t.string :suggested_name
      t.json :answers, default: {}, null: false
      t.integer :filled_count, default: 0, null: false
      t.timestamps
    end
  end
end
