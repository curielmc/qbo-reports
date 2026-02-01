class CreateHouseholdUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :household_users do |t|
      t.references :household, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: 'client'  # advisor, client
      t.timestamps
    end

    add_index :household_users, [:household_id, :user_id], unique: true
  end
end
