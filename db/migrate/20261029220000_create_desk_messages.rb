class CreateDeskMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :desk_messages do |t|
      t.string :whatsapp_number, null: false
      t.string :name
      t.string :email
      t.text :body, null: false
      t.string :direction, null: false, default: "inbound"
      t.string :intent
      t.string :external_id
      t.references :professor, foreign_key: true
      t.timestamps
    end

    add_index :desk_messages, :whatsapp_number
    add_index :desk_messages, :external_id, unique: true, where: "external_id IS NOT NULL"
    add_index :desk_messages, :created_at
  end
end
