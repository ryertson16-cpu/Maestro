class CreateSeriesMonitoring < ActiveRecord::Migration[8.1]
  def change
    create_table :series_bimester_settings do |t|
      t.references :professor, null: false, foreign_key: true
      t.references :grade_level, null: false, foreign_key: true
      t.integer :bimester, null: false
      t.decimal :target_average, precision: 3, scale: 1
      t.timestamps
    end

    add_index :series_bimester_settings,
              [ :professor_id, :grade_level_id, :bimester ],
              unique: true,
              name: "index_series_bimester_settings_uniqueness"
    add_check_constraint :series_bimester_settings,
                         "bimester BETWEEN 1 AND 4",
                         name: "series_bimester_settings_bimester_range"

    create_table :bimester_actions do |t|
      t.references :professor, null: false, foreign_key: true
      t.references :grade_level, null: false, foreign_key: true
      t.integer :bimester, null: false
      t.integer :position, null: false, default: 1
      t.string :title, null: false
      t.string :audience
      t.date :due_on
      t.timestamps
    end

    add_index :bimester_actions,
              [ :professor_id, :grade_level_id, :bimester, :position ],
              name: "index_bimester_actions_on_series_and_position"
    add_check_constraint :bimester_actions,
                         "bimester BETWEEN 1 AND 4",
                         name: "bimester_actions_bimester_range"
    add_check_constraint :bimester_actions,
                         "position >= 1",
                         name: "bimester_actions_position_positive"
  end
end
