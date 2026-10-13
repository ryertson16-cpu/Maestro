class CreateAutomationAgent < ActiveRecord::Migration[8.1]
  def change
    create_table :automation_rules do |t|
      t.references :professor, null: false, foreign_key: true
      t.string :kind, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :hour, null: false, default: 7
      t.integer :minute, null: false, default: 30
      t.date :last_run_on
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :automation_rules,
              %i[professor_id kind],
              unique: true

    create_table :automation_notices do |t|
      t.references :professor, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.string :url
      t.string :fingerprint, null: false
      t.datetime :read_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :automation_notices,
              %i[professor_id fingerprint],
              unique: true
    add_index :automation_notices, %i[professor_id read_at]
  end
end
