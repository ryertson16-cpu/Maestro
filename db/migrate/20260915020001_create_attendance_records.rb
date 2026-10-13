class CreateAttendanceRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :attendance_records do |t|
      t.references :professor, null: false, foreign_key: true
      t.references :enrollment, null: false, foreign_key: true
      t.date :attendance_date, null: false
      t.string :status, null: false, default: "present"
      t.text :notes

      t.timestamps
    end

    add_index :attendance_records,
              [:enrollment_id, :attendance_date],
              unique: true,
              name: "index_attendance_records_on_enrollment_and_date"
  end
end
