class CreateClientMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :client_messages do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.jsonb :mentioned_user_ids, default: []
      t.timestamps
    end

    add_index :client_messages, [:company_id, :created_at]
  end
end
