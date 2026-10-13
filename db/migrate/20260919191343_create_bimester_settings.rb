class CreateBimesterSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :bimester_settings do |t|
      t.references :classroom, null: false, foreign_key: true
      t.integer :bimester, null: false
      t.decimal :minimum_score,
                precision: 4,
                scale: 2,
                null: false,
                default: 6.0
      t.datetime :closed_at
      t.timestamps
    end

    add_index :bimester_settings,
              [:classroom_id, :bimester],
              unique: true

    add_check_constraint(
      :bimester_settings,
      "bimester BETWEEN 1 AND 4",
      name: "bimester_settings_bimester_between_one_and_four"
    )

    add_check_constraint(
      :bimester_settings,
      "minimum_score >= 0 AND minimum_score <= 10",
      name: "bimester_settings_minimum_score_between_zero_and_ten"
    )
  end
end
