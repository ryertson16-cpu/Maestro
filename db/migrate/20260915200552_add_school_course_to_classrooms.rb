class AddSchoolCourseToClassrooms < ActiveRecord::Migration[8.1]
  def change
    add_reference :classrooms,
                  :school_course,
                  foreign_key: true

    change_column_null :classrooms, :course_id, true
  end
end
