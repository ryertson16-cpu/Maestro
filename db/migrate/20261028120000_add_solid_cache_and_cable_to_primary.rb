class AddSolidCacheAndCableToPrimary < ActiveRecord::Migration[8.1]
  def change
    create_table :solid_cache_entries, if_not_exists: true do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536870912, null: false
      t.datetime :created_at, null: false
      t.integer :key_hash, limit: 8, null: false
      t.integer :byte_size, limit: 4, null: false
    end
    add_index :solid_cache_entries, :byte_size, if_not_exists: true
    add_index :solid_cache_entries, [ :key_hash, :byte_size ], if_not_exists: true
    add_index :solid_cache_entries, :key_hash, unique: true, if_not_exists: true

    create_table :solid_cable_messages, if_not_exists: true do |t|
      t.binary :channel, limit: 1024, null: false
      t.binary :payload, limit: 536870912, null: false
      t.datetime :created_at, null: false
      t.integer :channel_hash, limit: 8, null: false
    end
    add_index :solid_cable_messages, :channel, if_not_exists: true
    add_index :solid_cable_messages, :channel_hash, if_not_exists: true
    add_index :solid_cable_messages, :created_at, if_not_exists: true
  end
end
