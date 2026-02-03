class AddLedgerStatusToTransactions < ActiveRecord::Migration[6.1]
  def change
    add_column :transactions, :ledger_status, :string, default: 'pending', null: false
    add_index :transactions, :ledger_status

    # Existing categorized transactions should be marked as posted
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE transactions
          SET ledger_status = 'posted'
          WHERE chart_of_account_id IS NOT NULL
        SQL
      end
    end
  end
end
