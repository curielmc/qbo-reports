class CreateBoxSyncJobs < ActiveRecord::Migration[6.1]
  def change
    create_table :box_sync_jobs do |t|
      t.references :company, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, default: 'pending'
      t.integer :total_files, default: 0
      t.integer :processed_files, default: 0
      t.integer :imported_files, default: 0
      t.integer :skipped_files, default: 0
      t.integer :failed_files, default: 0
      t.text :current_file
      t.text :error_message
      t.jsonb :details, default: {}
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end
  end
end
