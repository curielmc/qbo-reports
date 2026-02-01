class EnhanceUsersAndRoles < ActiveRecord::Migration[6.1]
  def change
    # Invitation system
    create_table :invitations do |t|
      t.references :company, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :role, default: 'viewer' # owner, bookkeeper, editor, viewer
      t.string :token, null: false
      t.string :status, default: 'pending' # pending, accepted, expired, revoked
      t.datetime :accepted_at
      t.datetime :expires_at
      t.timestamps
    end

    # Audit trail
    create_table :audit_logs do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false  # create, update, delete, categorize, reconcile, etc.
      t.string :resource_type        # Transaction, JournalEntry, Reconciliation, etc.
      t.bigint :resource_id
      t.jsonb :changes_made          # { field: [old_value, new_value] }
      t.string :ip_address
      t.timestamps
    end

    # Notification preferences
    create_table :notifications do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :notification_type    # anomaly, low_balance, uncategorized, reconciliation_due
      t.string :title
      t.text :body
      t.boolean :read, default: false
      t.jsonb :data
      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, [:company_id, :email]
    add_index :audit_logs, [:company_id, :created_at]
    add_index :audit_logs, [:resource_type, :resource_id]
    add_index :notifications, [:user_id, :read]
  end
end
