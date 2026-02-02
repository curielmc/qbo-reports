class AddAgentTrackingToStatementUploads < ActiveRecord::Migration[6.1]
  def change
    add_column :statement_uploads, :source, :string, default: 'web', null: false
    add_column :statement_uploads, :parser_engine, :string
    add_reference :statement_uploads, :api_key, foreign_key: true, null: true
  end
end
