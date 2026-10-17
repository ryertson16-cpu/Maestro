class AddCadernoClassroomTools < ActiveRecord::Migration[8.1]
  def change
    add_column :lessons, :skills, :text unless column_exists?(:lessons, :skills)
    add_column :questions, :bncc_skill, :string unless column_exists?(:questions, :bncc_skill)
    add_column :activity_questions, :bncc_skill, :string unless column_exists?(:activity_questions, :bncc_skill)

    unless table_exists?(:student_occurrences)
      create_table :student_occurrences do |t|
        t.references :professor, null: false, foreign_key: true
        t.references :student, null: false, foreign_key: true
        t.references :classroom, foreign_key: true
        t.date :occurred_on, null: false
        t.string :kind, null: false, default: "other"
        t.text :body, null: false
        t.timestamps
      end

      add_index :student_occurrences, [:student_id, :occurred_on]
    end
  end
end
