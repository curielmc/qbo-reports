class CreateStatementUploads < ActiveRecord::Migration[6.1]
  def change
    create_table :statement_uploads do |t|
      t.references :company, null: false, foreign_key: true
      t.references :account, foreign_key: true  # linked after parsing
      t.references :user, null: false, foreign_key: true
      t.string :filename, null: false
      t.string :file_type  # csv, ofx, qfx, pdf
      t.string :status, default: 'pending'  # pending, parsing, parsed, imported, failed
      t.integer :transactions_found, default: 0
      t.integer :transactions_imported, default: 0
      t.integer :transactions_categorized, default: 0
      t.text :parse_notes  # AI notes about parsing decisions
      t.text :error_message
      t.jsonb :raw_data, default: {}  # parsed but not yet imported transactions
      t.timestamps
    end
  end
end
