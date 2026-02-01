module Api
  module V1
    class ReconciliationsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # POST /api/v1/companies/:company_id/reconciliations
      def create
        svc = ReconciliationService.new(@company, current_user)
        result = svc.start(
          account_id: params[:account_id],
          statement_date: params[:statement_date],
          statement_balance: params[:statement_balance]
        )
        render json: result
      end

      # GET /api/v1/companies/:company_id/reconciliations
      def index
        recons = @company.reconciliations.order(created_at: :desc).limit(20)
        render json: recons.map { |r|
          {
            id: r.id,
            account: r.account.name,
            statement_date: r.statement_date,
            statement_balance: r.statement_balance,
            difference: r.difference,
            status: r.status,
            created_at: r.created_at
          }
        }
      end

      # GET /api/v1/companies/:company_id/reconciliations/:id
      def show
        recon = @company.reconciliations.find(params[:id])
        uncleared = recon.account.transactions
          .where('date <= ?', recon.statement_date)
          .where(reconciliation_status: ['uncleared', 'cleared'])
          .where('reconciliation_id IS NULL OR reconciliation_id = ?', recon.id)
          .order(date: :asc)

        render json: {
          reconciliation: {
            id: recon.id,
            account: recon.account.name,
            statement_date: recon.statement_date,
            statement_balance: recon.statement_balance,
            book_balance: recon.book_balance,
            difference: recon.difference,
            status: recon.status
          },
          transactions: uncleared.map { |t|
            {
              id: t.id,
              date: t.date,
              description: t.description || t.merchant_name,
              amount: t.amount,
              cleared: t.reconciliation_status == 'cleared'
            }
          }
        }
      end

      # PATCH /api/v1/companies/:company_id/reconciliations/:id/toggle
      def toggle
        svc = ReconciliationService.new(@company, current_user)
        result = svc.toggle_cleared(
          reconciliation_id: params[:id],
          transaction_id: params[:transaction_id]
        )
        render json: result
      end

      # PATCH /api/v1/companies/:company_id/reconciliations/:id/suggest
      def suggest
        svc = ReconciliationService.new(@company, current_user)
        result = svc.suggest_clears(reconciliation_id: params[:id])
        render json: result
      end

      # PATCH /api/v1/companies/:company_id/reconciliations/:id/finish
      def finish
        svc = ReconciliationService.new(@company, current_user)
        result = svc.finish(reconciliation_id: params[:id])
        render json: result
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end
    end
  end
end
