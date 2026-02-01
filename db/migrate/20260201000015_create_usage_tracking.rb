class CreateUsageTracking < ActiveRecord::Migration[6.1]
  def change
    # Track every AI query for billing
    create_table :ai_queries do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false           # categorize, report, chat, parse_statement, etc
      t.integer :input_tokens, default: 0
      t.integer :output_tokens, default: 0
      t.decimal :cost, precision: 10, scale: 6, default: 0  # actual AI cost
      t.decimal :billed_amount, precision: 10, scale: 2, default: 0  # what we charge
      t.text :query_summary                   # brief description for invoice
      t.timestamps
    end

    # Company billing configuration
    add_column :companies, :engagement_type, :string, default: 'flat_fee'  # flat_fee, hourly
    add_column :companies, :monthly_fee, :decimal, precision: 10, scale: 2, default: 0
    add_column :companies, :hourly_rate, :decimal, precision: 10, scale: 2, default: 0
    add_column :companies, :ai_credit_cents, :integer, default: 10000  # $100.00 in cents
    add_column :companies, :ai_credit_used_cents, :integer, default: 0
    add_column :companies, :per_query_cents, :integer, default: 5  # $0.05 per query after credit
    add_column :companies, :billing_cycle_start, :date
    add_column :companies, :billing_active, :boolean, default: true

    add_index :ai_queries, [:company_id, :created_at]
    add_index :ai_queries, [:company_id, :action]
  end
end
