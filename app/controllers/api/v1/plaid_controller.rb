module Api
  module V1
    class PlaidController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!

      # POST /api/v1/plaid/create_link_token
      # Creates a Plaid Link token for the frontend
      def create_link_token
        plaid = PlaidService.new
        link_token = plaid.create_link_token(user_id: current_user.id)

        if link_token
          render json: { link_token: link_token }
        else
          render json: { error: 'Unable to create link token' }, status: :service_unavailable
        end
      rescue => e
        render json: { error: e.message }, status: :service_unavailable
      end

      # POST /api/v1/plaid/exchange_token
      # Exchanges public token for access token after Link success
      def exchange_token
        plaid = PlaidService.new
        result = plaid.exchange_public_token(params[:public_token])

        # Store the access token securely
        plaid_item = PlaidItem.create!(
          company: company,
          access_token: result[:access_token],
          item_id: result[:item_id],
          institution_id: params[:institution_id],
          institution_name: params[:institution_name],
          status: 'active'
        )

        # Fetch and store accounts
        accounts = plaid.get_accounts(result[:access_token])
        accounts.each do |plaid_account|
          account = company.accounts.find_or_initialize_by(plaid_account_id: plaid_account.account_id)
          account.update!(
            name: plaid_account.name,
            official_name: plaid_account.official_name,
            account_type: plaid_account.type,
            account_subtype: plaid_account.subtype,
            mask: plaid_account.mask,
            institution: params[:institution_name],
            plaid_item: plaid_item,
            active: true,
            current_balance: plaid_account.balances.current,
            available_balance: plaid_account.balances.available
          )
        end

        render json: {
          message: 'Account linked successfully',
          item_id: plaid_item.item_id,
          accounts_count: accounts.length
        }, status: :created
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/v1/plaid/sync_transactions
      # Sync transactions for a company using transactions/sync
      def sync_transactions
        plaid = PlaidService.new
        items = company.plaid_items.active

        total_added = 0
        total_modified = 0
        total_removed = 0

        items.each do |item|
          result = plaid.sync_transactions(item.access_token, cursor: item.transaction_cursor)

          # Process added transactions
          result[:added].each do |txn|
            account = company.accounts.find_by(plaid_account_id: txn.account_id)
            next unless account

            transaction = Transaction.find_or_initialize_by(
              plaid_transaction_id: txn.transaction_id,
              company: company
            )
            transaction.update!(
              account: account,
              chart_of_account: auto_categorize(txn, company),
              date: txn.date,
              description: txn.name,
              amount: txn.amount * -1, # Plaid uses positive for debits
              category: txn.personal_finance_category&.primary,
              subcategory: txn.personal_finance_category&.detailed,
              pending: txn.pending,
              merchant_name: txn.merchant_name
            )
            total_added += 1
          end

          # Process modified transactions
          result[:modified].each do |txn|
            transaction = Transaction.find_by(plaid_transaction_id: txn.transaction_id)
            next unless transaction

            transaction.update!(
              date: txn.date,
              description: txn.name,
              amount: txn.amount * -1,
              pending: txn.pending,
              merchant_name: txn.merchant_name
            )
            total_modified += 1
          end

          # Process removed transactions
          result[:removed].each do |txn|
            Transaction.where(plaid_transaction_id: txn.transaction_id).destroy_all
            total_removed += 1
          end

          # Update cursor
          item.update!(transaction_cursor: result[:cursor])
        end

        render json: {
          message: 'Transactions synced',
          added: total_added,
          modified: total_modified,
          removed: total_removed
        }
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/v1/plaid/refresh_balances
      def refresh_balances
        plaid = PlaidService.new

        company.plaid_items.active.each do |item|
          accounts = plaid.get_balances(item.access_token)
          accounts.each do |plaid_account|
            account = company.accounts.find_by(plaid_account_id: plaid_account.account_id)
            next unless account
            account.update!(
              current_balance: plaid_account.balances.current,
              available_balance: plaid_account.balances.available
            )
          end
        end

        render json: { message: 'Balances refreshed' }
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # GET /api/v1/plaid/items
      def items
        items = company.plaid_items.includes(:accounts)
        render json: items.map { |item|
          {
            id: item.id,
            item_id: item.item_id,
            institution_name: item.institution_name,
            status: item.status,
            accounts: item.accounts.map { |a|
              {
                id: a.id,
                name: a.name,
                type: a.account_type,
                mask: a.mask,
                current_balance: a.current_balance,
                available_balance: a.available_balance
              }
            },
            last_synced: item.updated_at
          }
        }
      end

      # DELETE /api/v1/plaid/items/:id
      def remove_item
        item = company.plaid_items.find(params[:id])
        plaid = PlaidService.new
        plaid.remove_item(item.access_token)
        item.update!(status: 'removed')
        render json: { message: 'Item removed' }
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def company
        @company ||= if params[:company_id]
          current_user.accessible_companies.find(params[:company_id])
        else
          current_user.accessible_companies.first
        end
      end

      def auto_categorize(txn, company)
        # Auto-map Plaid category to chart of accounts
        category = txn.personal_finance_category&.primary&.downcase
        return nil unless category

        mapping = {
          'income' => 'income',
          'transfer_in' => 'income',
          'transfer_out' => 'expense',
          'loan_payments' => 'expense',
          'bank_fees' => 'expense',
          'entertainment' => 'expense',
          'food_and_drink' => 'expense',
          'general_merchandise' => 'expense',
          'general_services' => 'expense',
          'government_and_non_profit' => 'expense',
          'home_improvement' => 'expense',
          'medical' => 'expense',
          'personal_care' => 'expense',
          'rent_and_utilities' => 'expense',
          'transportation' => 'expense',
          'travel' => 'expense'
        }

        account_type = mapping[category] || 'expense'
        company.chart_of_accounts
          .where(account_type: account_type, active: true)
          .find_by('LOWER(name) LIKE ?', "%#{category.gsub('_', ' ')}%") ||
          company.chart_of_accounts.where(account_type: account_type, active: true).first
      end
    end
  end
end
