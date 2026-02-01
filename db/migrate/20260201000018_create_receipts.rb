class CreateReceipts < ActiveRecord::Migration[6.1]
  def change
    create_table :receipts do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :transaction, foreign_key: true, null: true # matched transaction
      t.string :file_url, null: false
      t.string :filename
      t.string :content_type
      t.string :status, default: 'pending' # pending, matched, unmatched, manual
      # AI-extracted fields
      t.string :vendor
      t.decimal :amount, precision: 15, scale: 2
      t.date :receipt_date
      t.text :description
      t.text :raw_text      # OCR/AI extracted text
      t.jsonb :ai_data       # full AI parse result
      t.timestamps
    end

    add_index :receipts, [:company_id, :status]
    add_index :receipts, [:company_id, :receipt_date]
  end
end
