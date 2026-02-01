class CreateChartOfAccounts < ActiveRecord::Migration[6.1]
  def change
    create_table :chart_of_accounts do |t|
      t.references :company, null: false, foreign_key: true
      t.string :code
      t.string :name, null: false
      t.string :account_type, null: false  # asset, liability, equity, income, expense
      t.boolean :active, default: true
      t.string :parent_code
      t.timestamps
    end

    add_index :chart_of_accounts, [:company_id, :code], unique: true
    add_index :chart_of_accounts, [:company_id, :account_type]
  end
end
