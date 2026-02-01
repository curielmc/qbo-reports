class AddRolesToCompanyUsers < ActiveRecord::Migration[6.1]
  def change
    unless column_exists?(:company_users, :role)
      add_column :company_users, :role, :string, default: 'viewer'
      # owner, bookkeeper, editor, viewer
    end

    add_index :company_users, [:company_id, :role] unless index_exists?(:company_users, [:company_id, :role])
  end
end
