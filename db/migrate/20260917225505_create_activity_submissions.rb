class CreateActivitySubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_submissions do |t|
      t.references :activity,
                   null: false,
                   foreign_key: true

      t.references :student,
                   null: false,
                   foreign_key: true

      t.references :professor,
                   null: false,
                   foreign_key: true

      t.date :submitted_on

      t.timestamps
    end

    add_index :activity_submissions,
              [:activity_id, :student_id],
              unique: true,
              name: "index_activity_submissions_on_activity_and_student"
  end
end
