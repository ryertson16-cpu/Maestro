class CreateSiageRosterTables < ActiveRecord::Migration[8.1]
  def change
    create_table :siage_classroom_bindings do |t|
      t.references :professor, null: false, foreign_key: true
      t.references :classroom, null: false, foreign_key: true
      t.references :course, foreign_key: true
      t.string :siage_turma_id
      t.string :turma_name, null: false
      t.string :componente
      t.timestamps
    end

    add_index :siage_classroom_bindings,
              %i[professor_id siage_turma_id],
              unique: true,
              where: "siage_turma_id IS NOT NULL AND siage_turma_id != ''",
              name: "index_siage_bindings_unique_turma_id"
    add_index :siage_classroom_bindings,
              %i[classroom_id course_id],
              name: "index_siage_bindings_on_classroom_and_course"

    create_table :siage_roster_imports do |t|
      t.references :professor, null: false, foreign_key: true
      t.string :status, null: false, default: "pending_review"
      t.json :payload, null: false, default: {}
      t.json :preview, default: {}
      t.text :error_message
      t.datetime :applied_at
      t.timestamps
    end

    add_index :siage_roster_imports, %i[professor_id created_at]
  end
end
