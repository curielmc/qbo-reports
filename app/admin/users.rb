ActiveAdmin.register User do
  permit_params :email, :password, :password_confirmation, :first_name, :last_name, :role

  index do
    selectable_column
    id_column
    column :email
    column :first_name
    column :last_name
    column :role
    column :created_at
    actions
  end

  filter :email
  filter :first_name
  filter :last_name
  filter :role, as: :select, collection: User.roles.keys

  form do |f|
    f.inputs do
      f.input :email
      f.input :first_name
      f.input :last_name
      f.input :role, as: :select, collection: User.roles.keys
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end

  show do
    attributes_table do
      row :email
      row :first_name
      row :last_name
      row :role
      row :created_at
      row :updated_at
    end

    panel "Households" do
      table_for user.households do
        column :name
        column :created_at
      end
    end
  end
end
