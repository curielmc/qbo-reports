class CreatePlaidItems < ActiveRecord::Migration[6.1]
  def change
    create_table :plaid_items do |t|
      t.references :company, null: false, foreign_key: true
      t.string :access_token, null: false
      t.string :item_id, null: false
      t.string :institution_id
      t.string :institution_name
      t.string :status, null: false, default: 'active'
      t.string :transaction_cursor
      t.datetime :last_synced_at
      t.timestamps
    end

    add_index :plaid_items, :item_id, unique: true
    add_index :plaid_items, :status

    # Add Plaid columns to accounts
    add_column :accounts, :plaid_item_id, :bigint
    add_column :accounts, :official_name, :string
    add_column :accounts, :account_subtype, :string
    add_column :accounts, :current_balance, :decimal, precision: 15, scale: 2
    add_column :accounts, :available_balance, :decimal, precision: 15, scale: 2
    add_foreign_key :accounts, :plaid_items

    # Add Plaid columns to transactions
    add_column :transactions, :plaid_transaction_id, :string
    add_column :transactions, :category, :string
    add_column :transactions, :subcategory, :string
    add_column :transactions, :merchant_name, :string
    add_index :transactions, :plaid_transaction_id, unique: true
  end
end
