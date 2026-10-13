class CreateLessonsAndActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :lessons do |t|
      t.date :lesson_date, null: false
      t.string :theme, null: false
      t.text :content
      t.text :objective
      t.text :methodology
      t.boolean :has_activity, default: false, null: false

      t.references :professor,
                   null: false,
                   foreign_key: true

      t.references :classroom,
                   null: false,
                   foreign_key: true

      t.references :course,
                   null: true,
                   foreign_key: true

      t.timestamps
    end

    add_index :lessons,
              [:classroom_id, :lesson_date]

    create_table :activities do |t|
      t.string :title, null: false
      t.string :activity_type, null: false
      t.decimal :maximum_score,
                precision: 6,
                scale: 2

      t.date :due_date
      t.text :description
      t.text :instructions

      t.references :lesson,
                   null: false,
                   foreign_key: true

      t.timestamps
    end
  end
end
