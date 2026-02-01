ActiveAdmin.register Household do
  permit_params :name

  index do
    selectable_column
    id_column
    column :name
    column("Users") { |h| h.users.count }
    column("Accounts") { |h| h.accounts.count }
    column :created_at
    actions
  end

  filter :name

  form do |f|
    f.inputs do
      f.input :name
    end
    f.actions
  end

  show do
    attributes_table do
      row :name
      row :created_at
      row :updated_at
    end

    panel "Users" do
      table_for household.users do
        column :email
        column :first_name
        column :last_name
        column :role
      end
    end

    panel "Accounts" do
      table_for household.accounts do
        column :name
        column :institution
        column :account_type
        column :mask
      end
    end
  end
end
