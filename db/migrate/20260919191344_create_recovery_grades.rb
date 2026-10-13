class CreateRecoveryGrades < ActiveRecord::Migration[8.1]
  def change
    create_table :recovery_grades do |t|
      t.references :student, null: false, foreign_key: true
      t.references :classroom, null: false, foreign_key: true
      t.references :professor, null: false, foreign_key: true
      t.integer :bimester, null: false
      t.decimal :score,
                precision: 3,
                scale: 1,
                null: false
      t.text :notes
      t.timestamps
    end

    add_index :recovery_grades,
              [:student_id, :classroom_id, :bimester],
              unique: true

    add_check_constraint(
      :recovery_grades,
      "bimester BETWEEN 1 AND 4",
      name: "recovery_grades_bimester_between_one_and_four"
    )

    add_check_constraint(
      :recovery_grades,
      "score >= 0 AND score <= 10",
      name: "recovery_grades_score_between_zero_and_ten"
    )
  end
end
