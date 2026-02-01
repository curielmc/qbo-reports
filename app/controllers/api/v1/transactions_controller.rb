module Api
  module V1
    class TransactionsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/transactions
      def index
        transactions = @company.transactions
          .includes(:account, :chart_of_account)
          .order(date: :desc, created_at: :desc)

        # Date filters
        if params[:start_date].present?
          transactions = transactions.where('transactions.date >= ?', params[:start_date])
        end
        if params[:end_date].present?
          transactions = transactions.where('transactions.date <= ?', params[:end_date])
        end

        # Account filter
        if params[:account_id].present?
          transactions = transactions.where(account_id: params[:account_id])
        end

        # Category filter
        if params[:chart_of_account_id].present?
          transactions = transactions.where(chart_of_account_id: params[:chart_of_account_id])
        end

        # Pending filter
        if params[:pending].present?
          transactions = transactions.where(pending: params[:pending] == 'true')
        end

        # Uncategorized filter
        if params[:uncategorized] == 'true'
          transactions = transactions.where(chart_of_account_id: nil)
        end

        # Search
        if params[:search].present?
          transactions = transactions.where('description ILIKE ? OR merchant_name ILIKE ?',
            "%#{params[:search]}%", "%#{params[:search]}%")
        end

        # Pagination
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 50).to_i.clamp(1, 200)
        total = transactions.count
        transactions = transactions.offset((page - 1) * per_page).limit(per_page)

        render json: {
          transactions: transactions.map { |t| serialize(t) },
          pagination: {
            page: page,
            per_page: per_page,
            total: total,
            total_pages: (total.to_f / per_page).ceil
          }
        }
      end

      # POST /api/v1/companies/:company_id/transactions
      def create
        account = @company.accounts.find(params[:transaction][:account_id])
        transaction = account.transactions.build(transaction_params)
        if transaction.save
          render json: serialize(transaction), status: :created
        else
          render json: { errors: transaction.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/companies/:company_id/transactions/:id
      def update
        transaction = @company.transactions.find(params[:id])
        if transaction.update(transaction_params)
          render json: serialize(transaction)
        else
          render json: { errors: transaction.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/companies/:company_id/transactions/:id
      def destroy
        transaction = @company.transactions.find(params[:id])
        transaction.destroy
        render json: { message: 'Transaction deleted' }
      end

      # POST /api/v1/companies/:company_id/transactions/categorize
      # Bulk categorize uncategorized transactions
      def categorize
        ids = params[:transaction_ids] || []
        chart_of_account_id = params[:chart_of_account_id]

        updated = @company.transactions
          .where(id: ids)
          .update_all(chart_of_account_id: chart_of_account_id)

        render json: { message: "#{updated} transactions categorized" }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end

      def transaction_params
        params.require(:transaction).permit(:date, :description, :amount, :chart_of_account_id, :pending, :merchant_name)
      end

      def serialize(t)
        {
          id: t.id,
          date: t.date,
          description: t.description,
          amount: t.amount,
          pending: t.pending,
          merchant_name: t.merchant_name,
          category: t.category,
          subcategory: t.subcategory,
          account_id: t.account_id,
          account_name: t.account&.name,
          chart_of_account_id: t.chart_of_account_id,
          chart_of_account_name: t.chart_of_account&.name,
          plaid_transaction_id: t.plaid_transaction_id,
          categorized: t.categorized?,
          created_at: t.created_at
        }
      end
    end
  end
end
