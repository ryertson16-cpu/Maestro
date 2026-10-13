class AddSiageFieldsToLessons < ActiveRecord::Migration[8.1]
  def change
    add_column :lessons, :siage_period, :string
    add_column :lessons, :siage_class_mode, :string
    add_column :lessons, :siage_class_type, :string
    add_column :lessons, :siage_time_slot, :string
  end
end
