module Api
  module V1
    class ReportsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/reports/profit_loss
      def profit_loss
        start_date = params[:start_date] || Date.current.beginning_of_year
        end_date = params[:end_date] || Date.current

        income = {}
        @company.chart_of_accounts.income.active.each do |coa|
          amount = coa.transactions.where(date: start_date..end_date, pending: false).sum(:amount).abs
          income[coa.name] = amount if amount > 0
        end

        expenses = {}
        @company.chart_of_accounts.expense.active.each do |coa|
          amount = coa.transactions.where(date: start_date..end_date, pending: false).sum(:amount).abs
          expenses[coa.name] = amount if amount > 0
        end

        total_income = income.values.sum
        total_expenses = expenses.values.sum

        # AI summary (async-friendly)
        ai_summary = begin
          ReportSummarizer.new(@company).summarize_profit_loss(income, expenses, start_date, end_date)
        rescue => e
          Rails.logger.warn "AI summary failed: #{e.message}"
          nil
        end

        render json: {
          period: { start_date: start_date, end_date: end_date },
          income: income,
          expenses: expenses,
          total_income: total_income,
          total_expenses: total_expenses,
          net_income: total_income - total_expenses,
          ai_summary: ai_summary
        }
      end

      # GET /api/v1/companies/:company_id/reports/balance_sheet
      def balance_sheet
        as_of = params[:as_of_date] || Date.current

        assets = {}
        @company.chart_of_accounts.where(account_type: 'asset').active.each do |coa|
          balance = coa.transactions.where('date <= ?', as_of).sum(:amount)
          assets[coa.name] = balance if balance != 0
        end

        # Also include bank account balances
        @company.accounts.active.each do |account|
          if %w[checking savings depository investment brokerage].include?(account.account_type)
            assets[account.name] = account.current_balance if account.current_balance != 0
          end
        end

        liabilities = {}
        @company.chart_of_accounts.where(account_type: 'liability').active.each do |coa|
          balance = coa.transactions.where('date <= ?', as_of).sum(:amount).abs
          liabilities[coa.name] = balance if balance != 0
        end

        @company.accounts.active.each do |account|
          if %w[credit credit_card loan mortgage].include?(account.account_type)
            liabilities[account.name] = account.current_balance.abs if account.current_balance != 0
          end
        end

        equity = {}
        @company.chart_of_accounts.where(account_type: 'equity').active.each do |coa|
          balance = coa.transactions.where('date <= ?', as_of).sum(:amount)
          equity[coa.name] = balance if balance != 0
        end

        total_assets = assets.values.sum
        total_liabilities = liabilities.values.sum
        total_equity = equity.values.sum

        # Retained earnings = total_assets - total_liabilities - total_equity
        retained = total_assets - total_liabilities - total_equity
        equity['Retained Earnings'] = retained if retained != 0

        ai_summary = begin
          ReportSummarizer.new(@company).summarize_balance_sheet(assets, liabilities, equity)
        rescue => e
          nil
        end

        render json: {
          as_of_date: as_of,
          assets: assets,
          liabilities: liabilities,
          equity: equity,
          total_assets: total_assets,
          total_liabilities: total_liabilities,
          total_equity: total_equity + retained,
          ai_summary: ai_summary
        }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end
    end
  end
end
