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

    # Add Plaid columns to accounts (skip if already exist)
    if column_exists?(:accounts, :plaid_item_id)
      # Existing column may be a string; ensure it's bigint for FK reference
      col = ActiveRecord::Base.connection.columns(:accounts).find { |c| c.name == 'plaid_item_id' }
      change_column :accounts, :plaid_item_id, :bigint, using: 'plaid_item_id::bigint' unless col.sql_type =~ /int/
    else
      add_column :accounts, :plaid_item_id, :bigint
    end
    add_column :accounts, :official_name, :string unless column_exists?(:accounts, :official_name)
    add_column :accounts, :account_subtype, :string unless column_exists?(:accounts, :account_subtype)
    add_column :accounts, :current_balance, :decimal, precision: 15, scale: 2 unless column_exists?(:accounts, :current_balance)
    add_column :accounts, :available_balance, :decimal, precision: 15, scale: 2 unless column_exists?(:accounts, :available_balance)
    add_foreign_key :accounts, :plaid_items unless foreign_key_exists?(:accounts, :plaid_items)

    # Add Plaid columns to transactions (skip if already exist)
    add_column :transactions, :plaid_transaction_id, :string unless column_exists?(:transactions, :plaid_transaction_id)
    add_column :transactions, :category, :string unless column_exists?(:transactions, :category)
    add_column :transactions, :subcategory, :string unless column_exists?(:transactions, :subcategory)
    add_column :transactions, :merchant_name, :string unless column_exists?(:transactions, :merchant_name)
    add_index :transactions, :plaid_transaction_id, unique: true unless index_exists?(:transactions, :plaid_transaction_id)
  end
end
