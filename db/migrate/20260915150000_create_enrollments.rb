class CreateEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table :enrollments do |t|
      t.references :professor, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.references :classroom, null: false, foreign_key: true

      t.date :enrolled_on, null: false
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :enrollments,
              [:student_id, :classroom_id],
              unique: true,
              name: "index_enrollments_on_student_and_classroom"
  end
end
