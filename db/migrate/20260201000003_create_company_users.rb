class CreateCompanyUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :company_users do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: 'client'  # advisor, client
      t.timestamps
    end

    add_index :company_users, [:company_id, :user_id], unique: true
  end
end
