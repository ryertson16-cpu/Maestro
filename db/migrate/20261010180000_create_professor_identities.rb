class CreateProfessorIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :professor_identities do |t|
      t.references :professor, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :email
      t.string :name

      t.timestamps
    end

    add_index :professor_identities, [:provider, :uid], unique: true
    add_index :professor_identities, [:professor_id, :provider], unique: true
  end
end
