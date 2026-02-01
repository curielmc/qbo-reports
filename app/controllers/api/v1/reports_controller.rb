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

        # Pull from general ledger (journal lines), not raw transactions
        lines = JournalLine.joins(journal_entry: [], chart_of_account: [])
          .where(journal_entries: { company_id: @company.id, posted: true })
          .where(journal_entries: { entry_date: start_date..end_date })

        # Income = credits - debits on income accounts
        income = {}
        @company.chart_of_accounts.income.active.each do |coa|
          coa_lines = lines.where(chart_of_account: coa)
          balance = coa_lines.sum(:credit) - coa_lines.sum(:debit)
          income[coa.name] = balance.round(2) if balance > 0
        end

        # Expenses = debits - credits on expense accounts
        expenses = {}
        @company.chart_of_accounts.expense.active.each do |coa|
          coa_lines = lines.where(chart_of_account: coa)
          balance = coa_lines.sum(:debit) - coa_lines.sum(:credit)
          expenses[coa.name] = balance.round(2) if balance > 0
        end

        total_income = income.values.sum
        total_expenses = expenses.values.sum

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

        lines = JournalLine.joins(journal_entry: [], chart_of_account: [])
          .where(journal_entries: { company_id: @company.id, posted: true })
          .where('journal_entries.entry_date <= ?', as_of)

        # Assets = debits - credits (normal debit balance)
        assets = {}
        @company.chart_of_accounts.where(account_type: 'asset').active.each do |coa|
          coa_lines = lines.where(chart_of_account: coa)
          balance = coa_lines.sum(:debit) - coa_lines.sum(:credit)
          assets[coa.name] = balance.round(2) if balance.abs > 0.01
        end

        # Liabilities = credits - debits (normal credit balance)
        liabilities = {}
        @company.chart_of_accounts.where(account_type: 'liability').active.each do |coa|
          coa_lines = lines.where(chart_of_account: coa)
          balance = coa_lines.sum(:credit) - coa_lines.sum(:debit)
          liabilities[coa.name] = balance.round(2) if balance.abs > 0.01
        end

        # Equity = credits - debits (normal credit balance)
        equity = {}
        @company.chart_of_accounts.where(account_type: 'equity').active.each do |coa|
          coa_lines = lines.where(chart_of_account: coa)
          balance = coa_lines.sum(:credit) - coa_lines.sum(:debit)
          equity[coa.name] = balance.round(2) if balance.abs > 0.01
        end

        total_assets = assets.values.sum
        total_liabilities = liabilities.values.sum
        total_equity = equity.values.sum

        # Retained earnings = Assets - Liabilities - Equity (auto-balancing)
        retained = (total_assets - total_liabilities - total_equity).round(2)
        equity['Retained Earnings'] = retained if retained.abs > 0.01

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
          balanced: (total_assets - total_liabilities - total_equity - retained).abs < 0.01,
          ai_summary: ai_summary
        }
      end

      # GET /api/v1/companies/:company_id/reports/general_ledger
      def general_ledger
        start_date = params[:start_date] || Date.current.beginning_of_year
        end_date = params[:end_date] || Date.current
        coa_id = params[:chart_of_account_id]

        entries = @company.journal_entries.posted
          .where(entry_date: start_date..end_date)
          .includes(journal_lines: :chart_of_account)
          .order(entry_date: :asc)

        if coa_id.present?
          entries = entries.joins(:journal_lines).where(journal_lines: { chart_of_account_id: coa_id }).distinct
        end

        render json: {
          period: { start_date: start_date, end_date: end_date },
          entries: entries.map { |je|
            {
              id: je.id,
              date: je.entry_date,
              memo: je.memo,
              source: je.source,
              lines: je.journal_lines.map { |jl|
                {
                  account: jl.chart_of_account.name,
                  account_type: jl.chart_of_account.account_type,
                  debit: jl.debit,
                  credit: jl.credit,
                  memo: jl.memo
                }
              }
            }
          }
        }
      end

      # GET /api/v1/companies/:company_id/reports/trial_balance
      def trial_balance
        as_of = params[:as_of_date] || Date.current

        lines = JournalLine.joins(journal_entry: [], chart_of_account: [])
          .where(journal_entries: { company_id: @company.id, posted: true })
          .where('journal_entries.entry_date <= ?', as_of)

        accounts = @company.chart_of_accounts.active.order(:code).map do |coa|
          coa_lines = lines.where(chart_of_account: coa)
          total_debit = coa_lines.sum(:debit)
          total_credit = coa_lines.sum(:credit)
          balance = total_debit - total_credit

          next if total_debit == 0 && total_credit == 0

          {
            code: coa.code,
            name: coa.name,
            account_type: coa.account_type,
            debit: total_debit > total_credit ? balance.round(2) : 0,
            credit: total_credit > total_debit ? balance.abs.round(2) : 0
          }
        end.compact

        total_debits = accounts.sum { |a| a[:debit] }
        total_credits = accounts.sum { |a| a[:credit] }

        render json: {
          as_of_date: as_of,
          accounts: accounts,
          total_debits: total_debits.round(2),
          total_credits: total_credits.round(2),
          balanced: (total_debits - total_credits).abs < 0.01
        }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end
    end
  end
end
