class AddMaestroRoutineFeatures < ActiveRecord::Migration[8.1]
  def change
    create_table :siage_shipments do |t|
      t.references :professor, null: false, foreign_key: true
      t.references :classroom, null: false, foreign_key: true
      t.references :lesson, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "exported"
      t.string :filename
      t.text :notes
      t.integer :bimester
      t.datetime :exported_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :siage_shipments, %i[professor_id lesson_id]
    add_index :siage_shipments, %i[professor_id classroom_id kind]

    create_table :school_calendar_days do |t|
      t.references :professor, null: false, foreign_key: true
      t.date :day, null: false
      t.string :kind, null: false
      t.string :name
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :school_calendar_days, %i[professor_id day], unique: true

    create_table :timetable_entries do |t|
      t.references :professor, null: false, foreign_key: true
      t.references :classroom, null: false, foreign_key: true
      t.references :course, foreign_key: true
      t.integer :weekday, null: false
      t.integer :period, null: false
      t.string :time_slot
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :timetable_entries,
              %i[professor_id classroom_id weekday period],
              unique: true,
              name: "index_timetable_entries_unique_slot"

    create_table :council_notes do |t|
      t.references :professor, null: false, foreign_key: true
      t.references :classroom, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.integer :bimester, null: false
      t.text :body, null: false
      t.datetime :generated_at
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :council_notes,
              %i[professor_id classroom_id student_id bimester],
              unique: true,
              name: "index_council_notes_unique_student_bimester"

    create_table :lesson_plan_templates do |t|
      t.references :professor, null: false, foreign_key: true
      t.references :course, foreign_key: true
      t.string :title, null: false
      t.string :theme
      t.text :objective
      t.text :content
      t.text :methodology
      t.text :skills
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_reference :lessons, :lesson_plan_template, foreign_key: true
  end
end
