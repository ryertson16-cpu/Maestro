class AddSuggestedNameToEnemPendingCards < ActiveRecord::Migration[8.1]
  def change
    add_column :enem_pending_cards, :suggested_name, :string
    add_column :enem_pending_cards, :answers, :json, default: []
  end
end
