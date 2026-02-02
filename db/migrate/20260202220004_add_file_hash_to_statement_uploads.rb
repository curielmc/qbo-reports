class AddFileHashToStatementUploads < ActiveRecord::Migration[6.1]
  def change
    add_column :statement_uploads, :file_hash, :string
    add_index :statement_uploads, [:company_id, :file_hash]
  end
end
