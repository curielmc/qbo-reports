class CreateChatMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_messages do |t|
      t.references :user, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.string :role, null: false, default: 'user' # user, assistant
      t.text :content, null: false
      t.jsonb :metadata, default: {}  # stores query results, charts, actions taken
      t.timestamps
    end

    add_index :chat_messages, [:company_id, :created_at]
  end
end
