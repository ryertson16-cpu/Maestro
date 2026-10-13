class AddScoreToActivitySubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :activity_submissions,
              :score,
              :decimal,
              precision: 3,
              scale: 1

    add_check_constraint(
      :activity_submissions,
      "score IS NULL OR (score >= 0 AND score <= 10)",
      name: "activity_submissions_score_between_zero_and_ten"
    )
  end
end
