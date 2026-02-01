class PlaidService
  PRODUCTS = %w[transactions].freeze
  COUNTRY_CODES = %w[US].freeze

  def initialize
    configuration = Plaid::Configuration.new
    configuration.server_index = Plaid::Configuration::Environment[plaid_env]
    configuration.api_key["PLAID-CLIENT-ID"] = plaid_client_id
    configuration.api_key["PLAID-SECRET"] = plaid_secret
    api_client = Plaid::ApiClient.new(configuration)
    @client = Plaid::PlaidApi.new(api_client)
  end

  # --- Link Token ---

  def create_link_token(user_id:, client_name: 'ecfoBooks')
    request = Plaid::LinkTokenCreateRequest.new(
      user: { client_user_id: user_id.to_s },
      client_name: client_name,
      products: PRODUCTS,
      country_codes: COUNTRY_CODES,
      language: 'en'
    )
    response = @client.link_token_create(request)
    response.link_token
  end

  # Create link token for update mode (re-auth)
  def create_update_link_token(user_id:, access_token:, client_name: 'ecfoBooks')
    request = Plaid::LinkTokenCreateRequest.new(
      user: { client_user_id: user_id.to_s },
      client_name: client_name,
      access_token: access_token,
      country_codes: COUNTRY_CODES,
      language: 'en'
    )
    response = @client.link_token_create(request)
    response.link_token
  end

  # --- Token Exchange ---

  def exchange_public_token(public_token)
    request = Plaid::ItemPublicTokenExchangeRequest.new(public_token: public_token.to_s)
    response = @client.item_public_token_exchange(request)
    { access_token: response.access_token, item_id: response.item_id }
  end

  # --- Accounts ---

  def get_accounts(access_token)
    request = Plaid::AccountsGetRequest.new(access_token: access_token)
    response = @client.accounts_get(request)
    response.accounts
  end

  def get_balances(access_token, account_ids: nil)
    opts = { access_token: access_token }
    opts[:options] = { account_ids: account_ids } if account_ids.present?
    request = Plaid::AccountsBalanceGetRequest.new(opts)
    response = @client.accounts_balance_get(request)
    response.accounts
  end

  # --- Transactions (sync-based, recommended approach) ---

  def sync_transactions(access_token, cursor: nil)
    all_added = []
    all_modified = []
    all_removed = []
    has_more = true
    current_cursor = cursor

    while has_more
      request = Plaid::TransactionsSyncRequest.new(
        access_token: access_token,
        cursor: current_cursor
      )
      response = @client.transactions_sync(request)

      all_added += response.added
      all_modified += response.modified
      all_removed += response.removed
      has_more = response.has_more
      current_cursor = response.next_cursor
    end

    {
      added: all_added,
      modified: all_modified,
      removed: all_removed,
      cursor: current_cursor
    }
  end

  # Legacy: get transactions by date range
  def get_transactions(access_token, start_date:, end_date:)
    transactions = []
    request = Plaid::TransactionsGetRequest.new(
      access_token: access_token,
      start_date: start_date.to_s,
      end_date: end_date.to_s
    )
    response = @client.transactions_get(request)
    transactions += response.transactions

    while transactions.length < response.total_transactions
      request = Plaid::TransactionsGetRequest.new(
        access_token: access_token,
        start_date: start_date.to_s,
        end_date: end_date.to_s,
        options: { offset: transactions.length }
      )
      response = @client.transactions_get(request)
      transactions += response.transactions
    end

    transactions
  end

  # --- Item Management ---

  def get_item(access_token)
    request = Plaid::ItemGetRequest.new(access_token: access_token)
    @client.item_get(request)
  end

  def remove_item(access_token)
    request = Plaid::ItemRemoveRequest.new(access_token: access_token)
    @client.item_remove(request)
  end

  # --- Institution ---

  def get_institution(institution_id)
    request = Plaid::InstitutionsGetByIdRequest.new(
      institution_id: institution_id,
      country_codes: COUNTRY_CODES,
      options: { include_optional_metadata: true }
    )
    response = @client.institutions_get_by_id(request)
    response.institution
  end

  # --- Investment Holdings ---

  def get_holdings(access_token)
    request = Plaid::InvestmentsHoldingsGetRequest.new(access_token: access_token)
    response = @client.investments_holdings_get(request)
    { holdings: response.holdings, securities: response.securities, accounts: response.accounts }
  rescue Plaid::ApiError => e
    Rails.logger.error("Plaid holdings error: #{e.message}")
    { holdings: [], securities: [], accounts: [] }
  end

  private

  def plaid_client_id
    ENV['PLAID_CLIENT_ID'] || Rails.application.credentials.dig(:plaid, :client_id)
  end

  def plaid_secret
    env_key = plaid_env.to_sym
    ENV['PLAID_SECRET'] || Rails.application.credentials.dig(:plaid, env_key, :secret)
  end

  def plaid_env
    ENV['PLAID_ENV'] || (Rails.env.production? ? 'production' : 'sandbox')
  end
end
