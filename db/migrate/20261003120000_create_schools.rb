class CreateSchools < ActiveRecord::Migration[8.1]
  def change
    create_table :schools do |t|
      t.references :professor, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :regional
      t.string :regional_other
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    reversible do |dir|
      dir.up do
        say_with_time "copy professor school_name into schools" do
          execute(<<~SQL.squish)
            INSERT INTO schools (professor_id, name, created_at, updated_at)
            SELECT id, school_name, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            FROM professors
            WHERE school_name IS NOT NULL AND TRIM(school_name) != ''
          SQL
        end
      end
    end
  end
end
