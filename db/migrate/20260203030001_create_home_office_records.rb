class CreateHomeOfficeRecords < ActiveRecord::Migration[6.1]
  def change
    create_table :home_office_records do |t|
      t.references :company, foreign_key: true, null: false
      t.integer :tax_year, null: false
      t.string :method, null: false  # 'simplified' or 'regular'

      # Square footage (both methods)
      t.integer :total_home_sq_ft
      t.integer :office_sq_ft
      t.decimal :business_use_percentage, precision: 5, scale: 2  # calculated or manual

      # Simplified method
      t.decimal :simplified_deduction, precision: 10, scale: 2  # $5 x sq ft, max $1,500

      # Regular method expenses (annual amounts)
      t.decimal :mortgage_interest, precision: 10, scale: 2
      t.decimal :real_estate_taxes, precision: 10, scale: 2
      t.decimal :rent_paid, precision: 10, scale: 2
      t.decimal :utilities, precision: 10, scale: 2
      t.decimal :insurance, precision: 10, scale: 2
      t.decimal :repairs_maintenance, precision: 10, scale: 2
      t.decimal :depreciation, precision: 10, scale: 2
      t.decimal :other_expenses, precision: 10, scale: 2

      # Calculated totals
      t.decimal :total_expenses, precision: 10, scale: 2
      t.decimal :deductible_amount, precision: 10, scale: 2  # total * business_use_pct

      t.text :notes
      t.timestamps

      t.index [:company_id, :tax_year], unique: true
    end
  end
end
