class AddCorrectionPinToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :correction_pin, :string
    add_index :activities, :correction_pin, unique: true
  end
end
