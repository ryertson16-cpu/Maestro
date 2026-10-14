class CreateLiraAgent < ActiveRecord::Migration[8.1]
  def change
    add_column :professors, :whatsapp_number, :string

    add_index :professors, :whatsapp_number, unique: true

    create_table :agent_conversations do |t|
      t.references :professor, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :external_id, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :agent_conversations,
              %i[professor_id channel external_id],
              unique: true,
              name: "index_agent_conversations_on_professor_channel_external"

    create_table :agent_messages do |t|
      t.references :agent_conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :body, null: false
      t.json :metadata, default: {}, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    add_index :agent_messages, :role
  end
end
