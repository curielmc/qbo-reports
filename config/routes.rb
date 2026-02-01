Rails.application.routes.draw do
  # Devise for users
  devise_for :users

  root 'home#index'

  # API routes
  namespace :api do
    namespace :v1 do
      # Auth endpoints
      post 'auth/login', to: 'sessions#create'
      delete 'auth/logout', to: 'sessions#destroy'
      get 'auth/me', to: 'sessions#show'

      # Admin routes
      namespace :admin do
        resources :users, only: [:index, :create, :update, :destroy]
        resources :companies, only: [:index, :create, :update, :destroy] do
          member do
            get :members
            post :members, action: :add_member
            put 'members/:user_id', action: :update_member
            delete 'members/:user_id', action: :remove_member
          end
        end
        resources :accounts, only: [:index, :create, :update, :destroy]
        resources :invitations, only: [:index, :create, :destroy] do
          member do
            post :resend
          end
        end
      end

      # Plaid
      scope :plaid do
        post 'create_link_token', to: 'plaid#create_link_token'
        post 'exchange_token', to: 'plaid#exchange_token'
        post 'sync_transactions', to: 'plaid#sync_transactions'
        post 'refresh_balances', to: 'plaid#refresh_balances'
        get 'items', to: 'plaid#items'
        delete 'items/:id', to: 'plaid#remove_item'
      end

      # Public invitation endpoints
      get 'invitations/:token', to: 'invitations#show'
      post 'invitations/:token/accept', to: 'invitations#accept'

      # Dashboard
      get 'dashboard', to: 'dashboard#show'

      resources :companies, only: [:index, :show] do
        resources :accounts, only: [:index, :create, :update, :destroy]
        resources :transactions, only: [:index, :create, :update, :destroy] do
          collection do
            post :categorize
          end
        end
        resources :chart_of_accounts, only: [:index, :create, :update, :destroy]
        resources :categorization_rules, only: [:index, :create, :update, :destroy] do
          collection do
            post :run
            get :suggestions
          end
        end
        
        # Chat
        get 'chat', to: 'chat#index'
        post 'chat', to: 'chat#create'
        delete 'chat', to: 'chat#destroy'

        # Reports (all driven by general ledger / journal entries)
        get 'reports/profit_loss', to: 'reports#profit_loss'
        get 'reports/balance_sheet', to: 'reports#balance_sheet'
        get 'reports/general_ledger', to: 'reports#general_ledger'
        get 'reports/trial_balance', to: 'reports#trial_balance'

        # Exports
        get 'exports/transactions', to: 'exports#transactions_csv'
        get 'exports/profit_loss', to: 'exports#profit_loss_csv'
        get 'exports/balance_sheet', to: 'exports#balance_sheet_csv'
        get 'exports/chart_of_accounts', to: 'exports#chart_of_accounts_csv'
      end
    end
  end

  # Vue router handles these client-side routes
  get '/dashboard', to: 'home#index'
  get '/reports', to: 'home#index'
  get '/chart-of-accounts', to: 'home#index'
  get '/transactions', to: 'home#index'
  get '/linked-accounts', to: 'home#index'
  get '/rules', to: 'home#index'
  get '/chat', to: 'home#index'
  get '/login', to: 'home#index'
  get '/admin/*path', to: 'home#index'
  get '/invite/:token', to: 'home#index'
end
