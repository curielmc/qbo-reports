ActiveAdmin.register Account do
  permit_params :name, :institution, :account_type, :mask, :plaid_account_id, :household_id, :active

  index do
    selectable_column
    id_column
    column :name
    column :institution
    column :account_type
    column :mask
    column :household
    column :active
    column :created_at
    actions
  end

  filter :name
  filter :institution
  filter :account_type
  filter :household
  filter :active

  form do |f|
    f.inputs do
      f.input :household
      f.input :name
      f.input :institution
      f.input :account_type
      f.input :mask
      f.input :plaid_account_id
      f.input :active
    end
    f.actions
  end
end
