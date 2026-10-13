class CreateCourseDisciplines < ActiveRecord::Migration[8.1]
  def change
    create_table :course_disciplines do |t|
      t.references :school_course, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.boolean :required, null: false, default: true

      t.timestamps
    end

    add_index :course_disciplines,
              [:school_course_id, :course_id],
              unique: true,
              name: "index_course_disciplines_unique_link"
  end
end
