class AddKnowledgeAreaToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses,
               :knowledge_area,
               :string,
               null: false,
               default: "matematica"

    add_index :courses, :knowledge_area
  end
end
