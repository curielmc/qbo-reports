class CreateBoxImportedFiles < ActiveRecord::Migration[6.1]
  def change
    create_table :box_imported_files do |t|
      t.references :company, null: false, foreign_key: true
      t.string :box_file_id, null: false
      t.string :filename
      t.string :box_folder_path
      t.references :statement_upload, foreign_key: true
      t.string :status, default: 'imported'
      t.text :error_message
      t.timestamps
    end

    add_index :box_imported_files, [:company_id, :box_file_id], unique: true
  end
end
