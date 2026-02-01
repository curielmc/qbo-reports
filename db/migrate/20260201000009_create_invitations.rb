class CreateInvitations < ActiveRecord::Migration[6.1]
  def change
    create_table :invitations do |t|
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.string :role, null: false, default: 'client'
      t.string :token, null: false
      t.references :company, foreign_key: true
      t.references :invited_by, foreign_key: { to_table: :users }
      t.datetime :accepted_at
      t.datetime :expires_at, null: false
      t.text :personal_message
      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, :email
  end
end
