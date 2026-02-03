class CreateCommentsAndMentions < ActiveRecord::Migration[6.1]
  def change
    create_table :comments do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :commentable_type, null: false
      t.bigint :commentable_id, null: false
      t.text :body, null: false
      t.timestamps
    end

    add_index :comments, [:commentable_type, :commentable_id]
    add_index :comments, [:company_id, :commentable_type, :commentable_id], name: 'idx_comments_company_commentable'
    add_index :comments, [:company_id, :created_at]

    create_table :mentions do |t|
      t.references :comment, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    add_index :mentions, [:user_id, :created_at]
  end
end
