class CreateActivityExamAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_exam_assignments do |t|
      t.references :activity, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.integer :slot, null: false
      t.json :item_order, null: false, default: []
      t.json :choice_maps, null: false, default: {}
      t.timestamps
    end

    add_index :activity_exam_assignments,
              [ :activity_id, :student_id ],
              unique: true,
              name: "index_exam_assignments_on_activity_and_student"
    add_check_constraint :activity_exam_assignments,
                         "slot >= 1",
                         name: "activity_exam_assignments_slot_positive"
  end
end
