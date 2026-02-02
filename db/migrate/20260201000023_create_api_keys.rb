class CreateApiKeys < ActiveRecord::Migration[6.1]
  def change
    create_table :api_keys do |t|
      t.references :user, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :prefix, null: false, limit: 8
      t.string :name, null: false
      t.string :permissions, array: true, default: []
      t.boolean :active, null: false, default: true
      t.datetime :expires_at
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :api_keys, :token_digest, unique: true
    add_index :api_keys, :prefix
    add_index :api_keys, [:user_id, :company_id]
  end
end
