class AddExamVersionCountToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :exam_version_count, :integer, null: false, default: 3
  end
end
