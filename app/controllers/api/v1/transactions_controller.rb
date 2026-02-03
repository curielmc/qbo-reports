module Api
  module V1
    class TransactionsController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :set_company

      # GET /api/v1/companies/:company_id/transactions
      def index
        transactions = @company.account_transactions
          .includes(:account, :chart_of_account)
          .order(date: :desc, created_at: :desc)

        # Ledger status filter (pending/posted/excluded)
        if params[:ledger_status].present?
          transactions = transactions.where(ledger_status: params[:ledger_status])
        end

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

        # Pending filter (bank pending, not ledger status)
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

      # GET /api/v1/companies/:company_id/transactions/accounts_summary
      # Returns accounts with balances and transaction counts for the card display
      def accounts_summary
        accounts = @company.accounts.includes(:account_transactions)

        summaries = accounts.map do |account|
          pending_count = account.account_transactions.ledger_pending.count
          posted_count = account.account_transactions.ledger_posted.count
          excluded_count = account.account_transactions.ledger_excluded.count

          {
            id: account.id,
            name: account.name,
            account_type: account.account_type,
            mask: account.mask,
            current_balance: account.current_balance,
            available_balance: account.available_balance,
            pending_count: pending_count,
            posted_count: posted_count,
            excluded_count: excluded_count,
            needs_attention: pending_count > 0
          }
        end

        render json: { accounts: summaries }
      end

      # GET /api/v1/companies/:company_id/transactions/status_counts
      # Returns counts for each ledger status (for tab badges)
      def status_counts
        base = @company.account_transactions
        base = base.where(account_id: params[:account_id]) if params[:account_id].present?

        render json: {
          pending: base.ledger_pending.count,
          posted: base.ledger_posted.count,
          excluded: base.ledger_excluded.count
        }
      end

      # POST /api/v1/companies/:company_id/transactions
      def create
        account = @company.accounts.find(params[:transaction][:account_id])
        transaction = account.account_transactions.build(transaction_params)
        if transaction.save
          render json: serialize(transaction), status: :created
        else
          render json: { errors: transaction.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/companies/:company_id/transactions/:id
      def update
        transaction = @company.account_transactions.find(params[:id])
        if transaction.update(transaction_params)
          render json: serialize(transaction)
        else
          render json: { errors: transaction.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/companies/:company_id/transactions/:id
      def destroy
        transaction = @company.account_transactions.find(params[:id])
        transaction.destroy
        render json: { message: 'Transaction deleted' }
      end

      # POST /api/v1/companies/:company_id/transactions/categorize
      # Bulk categorize or recategorize transactions
      def categorize
        ids = params[:transaction_ids] || []
        chart_of_account_id = params[:chart_of_account_id]

        transactions = @company.account_transactions.where(id: ids)
        updated = 0

        transactions.find_each do |txn|
          if txn.update(chart_of_account_id: chart_of_account_id)
            updated += 1
          end
        end

        render json: { message: "#{updated} transactions categorized" }
      end

      # POST /api/v1/companies/:company_id/transactions/:id/post
      # Post a single transaction to the ledger
      def post_transaction
        transaction = @company.account_transactions.find(params[:id])

        unless transaction.categorized?
          return render json: { error: 'Transaction must be categorized before posting' }, status: :unprocessable_entity
        end

        transaction.post_to_ledger!
        render json: serialize(transaction)
      end

      # POST /api/v1/companies/:company_id/transactions/:id/exclude
      # Exclude a transaction from the ledger
      def exclude
        transaction = @company.account_transactions.find(params[:id])
        transaction.exclude_from_ledger!
        render json: serialize(transaction)
      end

      # POST /api/v1/companies/:company_id/transactions/:id/unpost
      # Move a transaction back to pending
      def unpost
        transaction = @company.account_transactions.find(params[:id])
        transaction.unpost!
        render json: serialize(transaction)
      end

      # POST /api/v1/companies/:company_id/transactions/bulk_post
      # Post multiple transactions at once
      def bulk_post
        ids = params[:transaction_ids] || []
        transactions = @company.account_transactions.where(id: ids)
        posted = 0
        errors = []

        transactions.find_each do |txn|
          if txn.categorized?
            txn.post_to_ledger!
            posted += 1
          else
            errors << "#{txn.description}: not categorized"
          end
        end

        render json: {
          message: "#{posted} transactions posted to ledger",
          errors: errors
        }
      end

      # POST /api/v1/companies/:company_id/transactions/bulk_exclude
      # Exclude multiple transactions at once
      def bulk_exclude
        ids = params[:transaction_ids] || []
        @company.account_transactions.where(id: ids).update_all(ledger_status: 'excluded')
        render json: { message: "#{ids.size} transactions excluded" }
      end

      private

      def set_company
        @company = current_user.accessible_companies.find(params[:company_id])
      end

      def transaction_params
        params.require(:transaction).permit(:date, :description, :amount, :chart_of_account_id, :pending, :merchant_name, :ledger_status)
      end

      def serialize(t)
        {
          id: t.id,
          date: t.date,
          description: t.description,
          amount: t.amount,
          pending: t.pending,
          ledger_status: t.ledger_status,
          merchant_name: t.merchant_name,
          category: t.category,
          subcategory: t.subcategory,
          account_id: t.account_id,
          account_name: t.account&.name,
          account_type: t.account&.account_type,
          chart_of_account_id: t.chart_of_account_id,
          chart_of_account_name: t.chart_of_account&.name,
          plaid_transaction_id: t.plaid_transaction_id,
          categorized: t.categorized?,
          posted: t.posted?,
          excluded: t.excluded?,
          created_at: t.created_at
        }
      end
    end
  end
end
