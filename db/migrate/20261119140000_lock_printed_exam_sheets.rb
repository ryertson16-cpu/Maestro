class LockPrintedExamSheets < ActiveRecord::Migration[8.1]
  def up
    add_column :activities, :exam_sheets_locked, :boolean, default: false, null: false
    add_column :activities, :exam_card_columns, :integer

    execute <<~SQL.squish
      UPDATE activities
      SET exam_sheets_locked = TRUE
      WHERE id IN (SELECT DISTINCT activity_id FROM activity_exam_assignments)
    SQL
  end

  def down
    remove_column :activities, :exam_card_columns
    remove_column :activities, :exam_sheets_locked
  end
end
