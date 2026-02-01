class CreateJournalEntryEnhancements < ActiveRecord::Migration[6.1]
  def change
    # Add fields for adjustments and recurring
    add_column :journal_entries, :entry_type, :string, default: 'standard'
    # standard, adjusting, closing, reversing, recurring, accrual, depreciation
    add_column :journal_entries, :reference_number, :string
    add_column :journal_entries, :approved_by_id, :bigint
    add_column :journal_entries, :approved_at, :datetime
    add_column :journal_entries, :reversed, :boolean, default: false
    add_column :journal_entries, :reversing_entry_id, :bigint
    add_column :journal_entries, :recurring_template_id, :bigint

    # Recurring journal entry templates
    create_table :recurring_entries do |t|
      t.references :company, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.text :memo
      t.string :frequency, default: 'monthly' # monthly, quarterly, annually, weekly
      t.date :start_date
      t.date :end_date
      t.date :next_run_date
      t.boolean :active, default: true
      t.boolean :auto_post, default: false  # Auto-post or create as draft
      t.jsonb :lines  # [{chart_of_account_id, debit, credit, memo}]
      t.integer :times_run, default: 0
      t.timestamps
    end

    # Journal entry templates (for common adjustments)
    create_table :journal_templates do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :entry_type, default: 'adjusting'
      t.jsonb :lines  # [{chart_of_account_id, debit_formula, credit_formula, memo}]
      t.boolean :system_template, default: false  # Built-in vs user-created
      t.timestamps
    end

    add_index :journal_entries, :entry_type
    add_index :journal_entries, :reference_number
    add_index :recurring_entries, [:company_id, :next_run_date]
  end
end
