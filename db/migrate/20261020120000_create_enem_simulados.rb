class CreateEnemSimulados < ActiveRecord::Migration[8.1]
  def change
    create_table :enem_simulados do |t|
      t.references :professor, null: false, foreign_key: true
      t.references :classroom, null: false, foreign_key: true
      t.references :activity, foreign_key: true
      t.string :title, null: false
      t.date :applied_on, null: false
      t.integer :bimester, null: false
      t.integer :question_count, null: false, default: 90
      t.json :official_key, null: false, default: []
      t.boolean :key_confirmed, null: false, default: false
      t.string :key_source
      t.timestamps
    end

    create_table :enem_simulado_sheets do |t|
      t.references :enem_simulado, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.json :answers, null: false, default: []
      t.integer :hits
      t.decimal :score, precision: 3, scale: 1
      t.boolean :confirmed, null: false, default: false
      t.string :suggestion_source
      t.timestamps
    end

    add_index :enem_simulado_sheets, %i[enem_simulado_id student_id], unique: true
  end
end
