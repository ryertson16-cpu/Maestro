class CreateEnemPendingCards < ActiveRecord::Migration[8.1]
  def change
    create_table :enem_pending_cards do |t|
      t.references :enem_simulado, null: false, foreign_key: true
      t.string :filename, null: false
      t.timestamps
    end
  end
end
