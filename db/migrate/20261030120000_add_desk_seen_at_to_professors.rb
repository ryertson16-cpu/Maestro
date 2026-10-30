class AddDeskSeenAtToProfessors < ActiveRecord::Migration[8.1]
  def change
    add_column :professors, :desk_seen_at, :datetime
  end
end
