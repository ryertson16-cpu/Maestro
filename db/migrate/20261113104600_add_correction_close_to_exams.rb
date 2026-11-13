class AddCorrectionCloseToExams < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :correction_closed_at, :datetime
    add_column :activity_submissions, :missed_exam, :boolean, null: false, default: false
  end
end