class AddLessonIdToAttendanceRecords < ActiveRecord::Migration[8.1]
  def change
    add_reference :attendance_records, :lesson, foreign_key: true, null: true

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE attendance_records
          SET lesson_id = (
            SELECT lessons.id
            FROM lessons
            INNER JOIN enrollments ON enrollments.classroom_id = lessons.classroom_id
            WHERE enrollments.id = attendance_records.enrollment_id
              AND lessons.lesson_date = attendance_records.attendance_date
            ORDER BY lessons.created_at ASC
            LIMIT 1
          )
          WHERE lesson_id IS NULL
        SQL
      end
    end
  end
end
