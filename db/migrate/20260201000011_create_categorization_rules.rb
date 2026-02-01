class CreateCategorizationRules < ActiveRecord::Migration[6.1]
  def change
    create_table :categorization_rules do |t|
      t.references :company, null: false, foreign_key: true
      t.references :chart_of_account, null: false, foreign_key: true
      t.string :match_type, null: false, default: 'contains'  # contains, exact, starts_with, regex
      t.string :match_field, null: false, default: 'description' # description, merchant_name, category
      t.string :match_value, null: false
      t.integer :priority, default: 0
      t.boolean :active, default: true
      t.integer :times_applied, default: 0
      t.timestamps
    end

    add_index :categorization_rules, [:company_id, :priority]
  end
end
