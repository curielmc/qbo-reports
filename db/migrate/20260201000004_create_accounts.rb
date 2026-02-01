class CreateAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table :accounts do |t|
      t.references :household, null: false, foreign_key: true
      t.string :name, null: false
      t.string :account_type, null: false  # checking, savings, credit_card, investment, loan, mortgage, other
      t.string :plaid_account_id
      t.string :plaid_item_id
      t.decimal :current_balance, precision: 15, scale: 2, default: 0
      t.decimal :available_balance, precision: 15, scale: 2, default: 0
      t.string :mask  # Last 4 digits
      t.string :official_name
      t.timestamps
    end

    add_index :accounts, :plaid_account_id, unique: true
    add_index :accounts, [:household_id, :account_type]
  end
end
