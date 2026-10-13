class UpdateStudentsFields < ActiveRecord::Migration[8.1]
  def change
    remove_column :students, :email, :string
    remove_column :students, :birth_date, :date

    add_reference :students, :course, null: true, foreign_key: true
    add_reference :students, :classroom, null: true, foreign_key: true
    add_column :students, :series, :string
  end
end
