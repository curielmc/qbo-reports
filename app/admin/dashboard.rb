ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    columns do
      column do
        panel "Recent Households" do
          table_for Household.order(created_at: :desc).limit(10) do
            column :name
            column :created_at
            column("Accounts") { |h| h.accounts.count }
          end
        end
      end

      column do
        panel "Statistics" do
          ul do
            li "Total Households: #{Household.count}"
            li "Total Users: #{User.count}"
            li "Total Accounts: #{Account.count}"
            li "Total Transactions: #{Transaction.count rescue 0}"
          end
        end
      end
    end
  end
end
