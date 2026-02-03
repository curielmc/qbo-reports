class CreateVehicleRecords < ActiveRecord::Migration[6.1]
  def change
    create_table :vehicle_records do |t|
      t.references :company, foreign_key: true, null: false
      t.integer :tax_year, null: false
      t.string :vehicle_description  # "2020 Toyota Camry"
      t.date :date_placed_in_service
      t.string :method, null: false  # 'standard_mileage' or 'actual'

      # Mileage tracking (both methods need this for business use %)
      t.integer :total_miles
      t.integer :business_miles
      t.integer :commuting_miles
      t.integer :personal_miles
      t.decimal :business_use_percentage, precision: 5, scale: 2

      # Standard mileage method
      t.decimal :mileage_rate, precision: 5, scale: 3  # e.g., 0.670 for 67 cents
      t.decimal :standard_mileage_deduction, precision: 10, scale: 2

      # Actual expense method
      t.decimal :gas_fuel, precision: 10, scale: 2
      t.decimal :oil_changes, precision: 10, scale: 2
      t.decimal :repairs_maintenance, precision: 10, scale: 2
      t.decimal :insurance, precision: 10, scale: 2
      t.decimal :registration_fees, precision: 10, scale: 2
      t.decimal :lease_payments, precision: 10, scale: 2
      t.decimal :loan_interest, precision: 10, scale: 2
      t.decimal :depreciation, precision: 10, scale: 2
      t.decimal :parking_tolls, precision: 10, scale: 2  # Always deductible, not prorated
      t.decimal :other_expenses, precision: 10, scale: 2

      # Calculated totals
      t.decimal :total_actual_expenses, precision: 10, scale: 2
      t.decimal :deductible_amount, precision: 10, scale: 2

      t.text :notes
      t.timestamps

      t.index [:company_id, :tax_year]
    end
  end
end
