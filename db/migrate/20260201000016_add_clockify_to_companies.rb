class AddClockifyToCompanies < ActiveRecord::Migration[6.1]
  def change
    add_column :companies, :clockify_project_id, :string
    add_column :companies, :clockify_client_id, :string
  end
end
