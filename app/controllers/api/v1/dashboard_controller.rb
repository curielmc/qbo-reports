module Api
  module V1
    class DashboardController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!

      # GET /api/v1/dashboard
      def show
        companies = current_user.accessible_companies

        # Overall stats
        total_accounts = Account.where(company: companies).active.count
        total_transactions = Transaction.joins(:account).where(accounts: { company_id: companies.pluck(:id) }).count

        # YTD income/expense
        ytd_start = Date.current.beginning_of_year
        ytd_transactions = Transaction.joins(:account, :chart_of_account)
          .where(accounts: { company_id: companies.pluck(:id) })
          .where(date: ytd_start..Date.current)
          .where(pending: false)

        ytd_income = ytd_transactions
          .where(chart_of_accounts: { account_type: 'income' })
          .sum(:amount).abs

        ytd_expenses = ytd_transactions
          .where(chart_of_accounts: { account_type: 'expense' })
          .sum(:amount).abs

        # Total balances
        all_accounts = Account.where(company: companies).active
        total_assets = all_accounts
          .where(account_type: %w[checking savings depository investment brokerage])
          .sum(:current_balance)
        total_liabilities = all_accounts
          .where(account_type: %w[credit credit_card loan mortgage])
          .sum(:current_balance).abs

        # Recent transactions
        recent = Transaction.joins(:account)
          .includes(:account, :chart_of_account)
          .where(accounts: { company_id: companies.pluck(:id) })
          .order(date: :desc)
          .limit(10)

        # Uncategorized count
        uncategorized = Transaction.joins(:account)
          .where(accounts: { company_id: companies.pluck(:id) })
          .where(chart_of_account_id: nil)
          .count

        # Monthly spending trend (last 6 months)
        monthly_spending = (0..5).map do |i|
          month_start = i.months.ago.beginning_of_month
          month_end = i.months.ago.end_of_month
          total = Transaction.joins(:account, :chart_of_account)
            .where(accounts: { company_id: companies.pluck(:id) })
            .where(chart_of_accounts: { account_type: 'expense' })
            .where(date: month_start..month_end)
            .where(pending: false)
            .sum(:amount).abs
          {
            month: month_start.strftime('%b %Y'),
            amount: total
          }
        end.reverse

        render json: {
          stats: {
            companies: companies.count,
            accounts: total_accounts,
            transactions: total_transactions,
            uncategorized: uncategorized
          },
          financials: {
            ytd_income: ytd_income,
            ytd_expenses: ytd_expenses,
            net_income: ytd_income - ytd_expenses,
            total_assets: total_assets,
            total_liabilities: total_liabilities,
            net_worth: total_assets - total_liabilities
          },
          monthly_spending: monthly_spending,
          alerts: companies.flat_map { |c| AnomalyDetector.new(c).check_all }.first(5),
          recent_transactions: recent.map { |t|
            {
              id: t.id,
              date: t.date,
              description: t.description,
              amount: t.amount,
              account_name: t.account&.name,
              chart_of_account_name: t.chart_of_account&.name,
              pending: t.pending
            }
          }
        }
      end
    end
  end
end
