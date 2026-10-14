class CreateQuestionBankAndActivityItems < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.references :professor, null: false, foreign_key: true
      t.references :course, foreign_key: true
      t.text :prompt, null: false
      t.string :kind, null: false, default: "objective"
      t.json :choices, default: [], null: false
      t.string :correct_letter
      t.decimal :points, precision: 6, scale: 2, default: 1.0, null: false
      t.string :tag
      t.timestamps
    end

    add_index :questions, :kind
    add_index :questions, :tag

    create_table :activity_questions do |t|
      t.references :activity, null: false, foreign_key: true
      t.references :question, foreign_key: true
      t.integer :position, null: false, default: 1
      t.text :prompt, null: false
      t.string :kind, null: false, default: "objective"
      t.json :choices, default: [], null: false
      t.string :correct_letter
      t.decimal :points, precision: 6, scale: 2, default: 1.0, null: false
      t.timestamps
    end

    add_index :activity_questions, %i[activity_id position], unique: true

    add_column :activities, :correction_token, :string
    add_index :activities, :correction_token, unique: true

    add_column :activity_submissions, :answers, :json, default: {}, null: false
  end
end
