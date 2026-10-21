class AddAreaHitsAndClassroomToEnemSheets < ActiveRecord::Migration[8.1]
  def change
    add_reference :enem_simulado_sheets, :classroom, foreign_key: true
    add_column :enem_simulado_sheets, :cn_hits, :integer
    add_column :enem_simulado_sheets, :mt_hits, :integer
  end
end
