module Api
  module V1
    class ReportsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_household
      before_action :authorize_household_access

      # GET /api/v1/households/:household_id/reports/profit_loss
      def profit_loss
        start_date = parse_date(params[:start_date]) || Date.current.beginning_of_year
        end_date = parse_date(params[:end_date]) || Date.current

        # Income accounts
        income_accounts = @household.chart_of_accounts.income.active
        income_data = income_accounts.map do |coa|
          transactions = coa.transactions.where(date: start_date..end_date, pending: false)
          total = transactions.sum(:amount)
          {
            id: coa.id,
            code: coa.code,
            name: coa.name,
            amount: total.abs
          }
        end

        # Expense accounts
        expense_accounts = @household.chart_of_accounts.expense.active
        expense_data = expense_accounts.map do |coa|
          transactions = coa.transactions.where(date: start_date..end_date, pending: false)
          total = transactions.sum(:amount)
          {
            id: coa.id,
            code: coa.code,
            name: coa.name,
            amount: total.abs
          }
        end

        total_income = income_data.sum { |i| i[:amount] }
        total_expenses = expense_data.sum { |e| e[:amount] }
        net_income = total_income - total_expenses

        render json: {
          start_date: start_date.to_s,
          end_date: end_date.to_s,
          income: {
            accounts: income_data,
            total: total_income
          },
          expenses: {
            accounts: expense_data,
            total: total_expenses
          },
          net_income: net_income
        }
      end

      # GET /api/v1/households/:household_id/reports/balance_sheet
      def balance_sheet
        as_of_date = parse_date(params[:as_of_date]) || Date.current

        # Assets
        asset_accounts = @household.chart_of_accounts.asset.active
        asset_data = asset_accounts.map do |coa|
          transactions = coa.transactions.where("date <= ?", as_of_date)
          balance = transactions.sum(:amount)
          {
            id: coa.id,
            code: coa.code,
            name: coa.name,
            balance: balance
          }
        end

        # Liabilities
        liability_accounts = @household.chart_of_accounts.liability.active
        liability_data = liability_accounts.map do |coa|
          transactions = coa.transactions.where("date <= ?", as_of_date)
          balance = transactions.sum(:amount).abs
          {
            id: coa.id,
            code: coa.code,
            name: coa.name,
            balance: balance
          }
        end

        # Equity
        equity_accounts = @household.chart_of_accounts.equity.active
        equity_data = equity_accounts.map do |coa|
          transactions = coa.transactions.where("date <= ?", as_of_date)
          balance = transactions.sum(:amount)
          {
            id: coa.id,
            code: coa.code,
            name: coa.name,
            balance: balance
          }
        end

        total_assets = asset_data.sum { |a| a[:balance] }
        total_liabilities = liability_data.sum { |l| l[:balance] }
        total_equity = equity_data.sum { |e| e[:balance] }

        # Retained earnings = Net Income from beginning of time to date
        income_total = @household.transactions.joins(:chart_of_account)
                          .where(chart_of_accounts: { account_type: 'income' })
                          .where("transactions.date <= ?", as_of_date)
                          .sum(:amount).abs
        expense_total = @household.transactions.joins(:chart_of_account)
                           .where(chart_of_accounts: { account_type: 'expense' })
                           .where("transactions.date <= ?", as_of_date)
                           .sum(:amount).abs
        retained_earnings = income_total - expense_total

        render json: {
          as_of_date: as_of_date.to_s,
          assets: {
            accounts: asset_data,
            total: total_assets
          },
          liabilities: {
            accounts: liability_data,
            total: total_liabilities
          },
          equity: {
            accounts: equity_data,
            total: total_equity,
            retained_earnings: retained_earnings
          },
          total_liabilities_and_equity: total_liabilities + total_equity + retained_earnings
        }
      end

      private

      def set_household
        @household = Household.find(params[:household_id])
      end

      def authorize_household_access
        unless current_user.can_manage_household?(@household)
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end

      def parse_date(date_string)
        return nil if date_string.blank?
        Date.parse(date_string)
      rescue ArgumentError
        nil
      end
    end
  end
end
