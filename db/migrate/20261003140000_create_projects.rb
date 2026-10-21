class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :professor, null: false, foreign_key: true
      t.string :title, null: false
      t.string :kind, null: false
      t.string :kind_other
      t.string :audience, null: false
      t.string :status, null: false, default: "draft"
      t.date :starts_on
      t.date :ends_on
      t.text :objective
      t.text :justification
      t.text :skills
      t.text :team_notes
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :projects, %i[professor_id status]
    add_index :projects, %i[professor_id kind]

    create_table :project_classrooms do |t|
      t.references :project, null: false, foreign_key: true
      t.references :classroom, null: false, foreign_key: true
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :project_classrooms, %i[project_id classroom_id], unique: true

    create_table :project_stages do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :position, null: false, default: 1
      t.string :title, null: false
      t.text :description
      t.date :due_on
      t.string :status, null: false, default: "pending"
      t.references :lesson, foreign_key: true
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :project_stages, %i[project_id position]
  end
end
