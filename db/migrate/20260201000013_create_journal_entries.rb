class CreateJournalEntries < ActiveRecord::Migration[6.1]
  def change
    create_table :journal_entries do |t|
      t.references :company, null: false, foreign_key: true
      t.references :transaction, foreign_key: true  # linked Plaid/manual transaction (optional)
      t.date :entry_date, null: false
      t.string :memo
      t.string :source, default: 'auto'  # auto, manual, plaid, categorization
      t.boolean :posted, default: true
      t.timestamps
    end

    create_table :journal_lines do |t|
      t.references :journal_entry, null: false, foreign_key: true
      t.references :chart_of_account, null: false, foreign_key: true
      t.decimal :debit, precision: 15, scale: 2, default: 0
      t.decimal :credit, precision: 15, scale: 2, default: 0
      t.string :memo
      t.timestamps
    end

    add_index :journal_entries, [:company_id, :entry_date]
    add_index :journal_lines, [:chart_of_account_id, :created_at]
  end
end
