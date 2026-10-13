class AddBimesterAndWeightToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities,
              :bimester,
              :integer,
              null: false,
              default: 1

    add_column :activities,
              :weight,
              :decimal,
              precision: 5,
              scale: 2,
              null: false,
              default: 1.0

    add_check_constraint(
      :activities,
      "bimester BETWEEN 1 AND 4",
      name: "activities_bimester_between_one_and_four"
    )

    add_check_constraint(
      :activities,
      "weight > 0",
      name: "activities_weight_greater_than_zero"
    )
  end
end
