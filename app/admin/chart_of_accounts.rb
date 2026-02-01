ActiveAdmin.register ChartOfAccount do
  permit_params :code, :name, :account_type, :parent_id, :household_id, :active

  index do
    selectable_column
    id_column
    column :code
    column :name
    column :account_type
    column :household
    column :active
    column :created_at
    actions
  end

  filter :name
  filter :code
  filter :account_type, as: :select, collection: ChartOfAccount.account_types.keys
  filter :household
  filter :active

  form do |f|
    f.inputs do
      f.input :household
      f.input :code
      f.input :name
      f.input :account_type, as: :select, collection: ChartOfAccount.account_types.keys
      f.input :parent_id, as: :select, collection: ChartOfAccount.pluck(:name, :id)
      f.input :active
    end
    f.actions
  end
end
