class IndexAttendanceRecordsByLesson < ActiveRecord::Migration[8.1]
  def change
    remove_index :attendance_records,
                 name: "index_attendance_records_on_enrollment_and_date"

    add_index :attendance_records,
              %i[enrollment_id attendance_date lesson_id],
              unique: true,
              name: "index_attendance_records_on_enrollment_date_lesson"
  end
end
