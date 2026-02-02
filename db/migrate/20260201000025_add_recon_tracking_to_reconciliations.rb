class AddReconTrackingToReconciliations < ActiveRecord::Migration[6.1]
  def change
    add_column :reconciliations, :source, :string, default: 'manual', null: false
    add_reference :reconciliations, :statement_upload, foreign_key: true, null: true
  end
end
