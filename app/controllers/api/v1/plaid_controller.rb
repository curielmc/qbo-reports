module Api
  module V1
    class PlaidController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!

      # POST /api/v1/plaid/create_link_token
      def create_link_token
        company = current_user.accessible_companies.find(params[:company_id])

        client = plaid_client
        request = Plaid::LinkTokenCreateRequest.new({
          user: { client_user_id: current_user.id.to_s },
          client_name: 'ecfoBooks',
          products: ['transactions'],
          country_codes: ['US'],
          language: 'en'
        })

        response = client.link_token_create(request)
        render json: { link_token: response.link_token }
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/v1/plaid/exchange_token
      def exchange_token
        company = current_user.accessible_companies.find(params[:company_id])
        client = plaid_client

        exchange_request = Plaid::ItemPublicTokenExchangeRequest.new({ public_token: params[:public_token] })
        exchange_response = client.item_public_token_exchange(exchange_request)

        access_token = exchange_response.access_token
        item_id = exchange_response.item_id

        plaid_item = company.plaid_items.create!(
          access_token: access_token,
          item_id: item_id,
          institution_name: params[:institution_name] || 'Unknown'
        )

        # Fetch and create accounts
        accounts_response = client.accounts_get(
          Plaid::AccountsGetRequest.new({ access_token: access_token })
        )

        accounts_response.accounts.each do |pa|
          company.accounts.find_or_create_by(plaid_account_id: pa.account_id) do |a|
            a.plaid_item = plaid_item
            a.name = pa.name
            a.official_name = pa.official_name
            a.account_type = pa.type.to_s
            a.subtype = pa.subtype.to_s
            a.mask = pa.mask
            a.current_balance = pa.balances.current || 0
            a.available_balance = pa.balances.available
          end
        end

        render json: { message: 'Account linked', item_id: plaid_item.id }
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/v1/plaid/sync_transactions
      def sync_transactions
        plaid_item = PlaidItem.find(params[:plaid_item_id])
        company = plaid_item.company

        # Verify access
        current_user.accessible_companies.find(company.id)

        client = plaid_client
        added_count = 0
        modified_count = 0
        removed_count = 0
        cursor = plaid_item.transaction_cursor

        loop do
          request = Plaid::TransactionsSyncRequest.new({
            access_token: plaid_item.access_token,
            cursor: cursor
          })

          response = client.transactions_sync(request)

          # Process added transactions
          response.added.each do |pt|
            account = company.accounts.find_by(plaid_account_id: pt.account_id)
            next unless account

            account.transactions.find_or_create_by(plaid_transaction_id: pt.transaction_id) do |t|
              t.date = pt.date
              t.description = pt.name
              t.amount = -pt.amount # Plaid uses negative for debits
              t.pending = pt.pending
              t.merchant_name = pt.merchant_name
              t.category = pt.personal_finance_category&.primary
              t.subcategory = pt.personal_finance_category&.detailed
            end
            added_count += 1
          end

          # Process modified
          response.modified.each do |pt|
            txn = Transaction.find_by(plaid_transaction_id: pt.transaction_id)
            next unless txn
            txn.update(
              date: pt.date,
              description: pt.name,
              amount: -pt.amount,
              pending: pt.pending,
              merchant_name: pt.merchant_name
            )
            modified_count += 1
          end

          # Process removed
          response.removed.each do |pt|
            Transaction.find_by(plaid_transaction_id: pt.transaction_id)&.destroy
            removed_count += 1
          end

          cursor = response.next_cursor
          break unless response.has_more
        end

        plaid_item.update!(transaction_cursor: cursor, last_synced_at: Time.current)

        # Auto-categorize new transactions
        auto_categorized = CategorizationRule.auto_categorize(company)

        render json: {
          added: added_count,
          modified: modified_count,
          removed: removed_count,
          auto_categorized: auto_categorized,
          message: "Synced #{added_count} new, #{modified_count} modified, #{removed_count} removed. Auto-categorized #{auto_categorized}."
        }
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # POST /api/v1/plaid/refresh_balances
      def refresh_balances
        plaid_item = PlaidItem.find(params[:plaid_item_id])
        company = plaid_item.company
        current_user.accessible_companies.find(company.id)

        client = plaid_client
        response = client.accounts_get(
          Plaid::AccountsGetRequest.new({ access_token: plaid_item.access_token })
        )

        response.accounts.each do |pa|
          account = company.accounts.find_by(plaid_account_id: pa.account_id)
          next unless account
          account.update!(
            current_balance: pa.balances.current || 0,
            available_balance: pa.balances.available
          )
        end

        render json: { message: 'Balances refreshed' }
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # GET /api/v1/plaid/items
      def items
        companies = current_user.accessible_companies
        plaid_items = PlaidItem.where(company: companies).includes(company: :accounts)

        render json: plaid_items.map { |item|
          {
            id: item.id,
            institution_name: item.institution_name,
            last_synced_at: item.last_synced_at,
            created_at: item.created_at,
            accounts: item.company.accounts.where(plaid_item: item).map { |a|
              {
                id: a.id,
                name: a.name,
                account_type: a.account_type,
                mask: a.mask,
                current_balance: a.current_balance,
                available_balance: a.available_balance,
                active: a.active
              }
            }
          }
        }
      end

      # DELETE /api/v1/plaid/items/:id
      def remove_item
        item = PlaidItem.find(params[:id])
        current_user.accessible_companies.find(item.company_id)

        # Remove from Plaid
        begin
          client = plaid_client
          client.item_remove(Plaid::ItemRemoveRequest.new({ access_token: item.access_token }))
        rescue => e
          Rails.logger.warn "Plaid item removal failed: #{e.message}"
        end

        item.destroy
        render json: { message: 'Item disconnected' }
      end

      private

      def plaid_client
        configuration = Plaid::Configuration.new
        configuration.server_index = Rails.env.production? ? Plaid::Configuration::Environment['production'] : Plaid::Configuration::Environment['sandbox']
        configuration.api_key['PLAID-CLIENT-ID'] = Rails.application.credentials.dig(:plaid, :client_id) || ENV['PLAID_CLIENT_ID']
        configuration.api_key['PLAID-SECRET'] = Rails.application.credentials.dig(:plaid, :secret) || ENV['PLAID_SECRET']
        Plaid::PlaidApi.new(Plaid::ApiClient.new(configuration))
      end
    end
  end
end
