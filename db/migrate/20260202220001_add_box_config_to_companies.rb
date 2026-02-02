class AddBoxConfigToCompanies < ActiveRecord::Migration[6.1]
  def change
    add_column :companies, :box_folder_url, :string
    add_column :companies, :box_developer_token, :string
    add_column :companies, :box_folder_id, :string
  end
end
