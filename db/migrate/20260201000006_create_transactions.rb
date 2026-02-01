class CreateTransactions < ActiveRecord::Migration[6.1]
  def change
    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :chart_of_account, foreign_key: true
      t.string :plaid_transaction_id
      t.string :name
      t.text :description
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.string :currency_code, default: 'USD'
      t.date :date, null: false
      t.datetime :datetime
      t.boolean :pending, default: false
      t.string :transaction_type  # debit, credit, special
      t.string :payment_channel   # online, in store, etc
      t.string :merchant_name
      t.jsonb :plaid_raw_data
      t.string :categorization_source, default: 'manual'  # plaid, ai, manual
      t.timestamps
    end

    add_index :transactions, :plaid_transaction_id, unique: true
    add_index :transactions, [:account_id, :date]
    add_index :transactions, [:chart_of_account_id, :date]
    add_index :transactions, :date
  end
end
