class CreateReconciliations < ActiveRecord::Migration[6.1]
  def change
    create_table :reconciliations do |t|
      t.references :company, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :statement_date, null: false
      t.decimal :statement_balance, precision: 15, scale: 2, null: false
      t.decimal :book_balance, precision: 15, scale: 2
      t.decimal :difference, precision: 15, scale: 2, default: 0
      t.string :status, default: 'in_progress' # in_progress, completed, discrepancy
      t.text :notes
      t.timestamps
    end

    # Track which transactions are cleared/reconciled
    add_column :transactions, :reconciliation_status, :string, default: 'uncleared'
    # uncleared → cleared → reconciled
    add_reference :transactions, :reconciliation, foreign_key: true, null: true

    add_index :reconciliations, [:company_id, :account_id, :statement_date]
    add_index :transactions, :reconciliation_status
  end
end
