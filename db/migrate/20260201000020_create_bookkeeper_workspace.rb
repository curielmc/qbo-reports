class CreateBookkeeperWorkspace < ActiveRecord::Migration[6.1]
  def change
    # Bookkeeper task queue — AI-generated work items
    create_table :bookkeeper_tasks do |t|
      t.references :company, null: false, foreign_key: true
      t.references :assigned_to, foreign_key: { to_table: :users }, null: true
      t.string :task_type, null: false  # categorize, reconcile, review_anomaly, close_month, follow_up, receipt_match
      t.string :priority, default: 'normal' # critical, high, normal, low
      t.string :status, default: 'pending'  # pending, in_progress, completed, dismissed
      t.string :title, null: false
      t.text :description
      t.jsonb :metadata          # task-specific data (transaction_ids, account_id, etc.)
      t.integer :estimated_minutes, default: 5
      t.datetime :due_date
      t.datetime :completed_at
      t.timestamps
    end

    # Track month-end close progress
    create_table :month_end_closes do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :period, null: false  # first of month (e.g. 2026-02-01)
      t.string :status, default: 'open' # open, in_progress, review, closed
      t.jsonb :checklist  # { step_name: { completed: bool, completed_by: user_id, completed_at: timestamp } }
      t.text :notes
      t.datetime :closed_at
      t.timestamps
    end

    add_index :bookkeeper_tasks, [:assigned_to_id, :status]
    add_index :bookkeeper_tasks, [:company_id, :status]
    add_index :bookkeeper_tasks, [:priority, :status]
    add_index :month_end_closes, [:company_id, :period], unique: true
  end
end
