module Api
  module V1
    class ExportsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/exports/transactions.csv
      def transactions_csv
        start_date = params[:start_date] || Date.current.beginning_of_year
        end_date = params[:end_date] || Date.current

        transactions = @company.account_transactions
          .includes(:account, :chart_of_account)
          .where(date: start_date..end_date)
          .order(date: :desc)

        csv_data = CSV.generate do |csv|
          csv << ['Date', 'Description', 'Amount', 'Account', 'Category', 'Merchant', 'Status', 'Plaid ID']
          transactions.each do |t|
            csv << [
              t.date,
              t.description,
              t.amount,
              t.account&.name,
              t.chart_of_account&.name || 'Uncategorized',
              t.merchant_name,
              t.pending ? 'Pending' : 'Cleared',
              t.plaid_transaction_id
            ]
          end
        end

        send_data csv_data,
          filename: "#{@company.name.parameterize}-transactions-#{start_date}-to-#{end_date}.csv",
          type: 'text/csv'
      end

      # GET /api/v1/companies/:company_id/exports/profit_loss.csv
      def profit_loss_csv
        start_date = params[:start_date] || Date.current.beginning_of_year
        end_date = params[:end_date] || Date.current

        csv_data = CSV.generate do |csv|
          csv << ["Profit & Loss - #{@company.name}", "#{start_date} to #{end_date}"]
          csv << []

          # Income
          csv << ['INCOME']
          income_total = 0
          @company.chart_of_accounts.income.active.each do |coa|
            amount = coa.account_transactions.where(date: start_date..end_date, pending: false).sum(:amount).abs
            next if amount.zero?
            csv << [coa.name, amount]
            income_total += amount
          end
          csv << ['Total Income', income_total]
          csv << []

          # Expenses
          csv << ['EXPENSES']
          expense_total = 0
          @company.chart_of_accounts.expense.active.each do |coa|
            amount = coa.account_transactions.where(date: start_date..end_date, pending: false).sum(:amount).abs
            next if amount.zero?
            csv << [coa.name, amount]
            expense_total += amount
          end
          csv << ['Total Expenses', expense_total]
          csv << []

          csv << ['NET INCOME', income_total - expense_total]
        end

        send_data csv_data,
          filename: "#{@company.name.parameterize}-profit-loss-#{start_date}-to-#{end_date}.csv",
          type: 'text/csv'
      end

      # GET /api/v1/companies/:company_id/exports/balance_sheet.csv
      def balance_sheet_csv
        as_of = params[:as_of_date] || Date.current

        csv_data = CSV.generate do |csv|
          csv << ["Balance Sheet - #{@company.name}", "As of #{as_of}"]
          csv << []

          %w[asset liability equity].each do |type|
            csv << [type.upcase.pluralize]
            total = 0
            @company.chart_of_accounts.where(account_type: type).active.each do |coa|
              balance = coa.account_transactions.where('date <= ?', as_of).sum(:amount)
              balance = balance.abs if type == 'liability'
              next if balance.zero?
              csv << [coa.name, balance]
              total += balance
            end
            csv << ["Total #{type.capitalize.pluralize}", total]
            csv << []
          end
        end

        send_data csv_data,
          filename: "#{@company.name.parameterize}-balance-sheet-#{as_of}.csv",
          type: 'text/csv'
      end

      # GET /api/v1/companies/:company_id/exports/chart_of_accounts.csv
      def chart_of_accounts_csv
        csv_data = CSV.generate do |csv|
          csv << ['Code', 'Name', 'Type', 'Active', 'Transactions Count']
          @company.chart_of_accounts.order(:account_type, :code).each do |coa|
            csv << [coa.code, coa.name, coa.account_type, coa.active, coa.account_transactions.count]
          end
        end

        send_data csv_data,
          filename: "#{@company.name.parameterize}-chart-of-accounts.csv",
          type: 'text/csv'
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end
    end
  end
end
