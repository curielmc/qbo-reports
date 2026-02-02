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

      # Dashboard
      get 'dashboard', to: 'dashboard#show'

      # Admin routes
      namespace :admin do
        resources :billing, only: [:index, :show, :update], param: :company_id do
          member do
            post :reset_credit
          end
        end

        # Clockify integration
        get 'clockify/projects', to: 'clockify#projects'
        get 'clockify/clients', to: 'clockify#clients'
        get 'clockify/summary', to: 'clockify#summary'
        post 'clockify/setup/:company_id', to: 'clockify#setup'
        post 'masquerade/:user_id', to: 'masquerade#create'
        delete 'masquerade', to: 'masquerade#destroy'
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

      # Bookkeeper workspace
      scope :bookkeeper do
        get 'dashboard', to: 'bookkeeper#dashboard'
        get 'tasks', to: 'bookkeeper#tasks'
        patch 'tasks/:id', to: 'bookkeeper#update_task'
        post 'generate_tasks', to: 'bookkeeper#generate_tasks'
        get 'anomalies/:company_id', to: 'bookkeeper#anomalies'
        get 'categorization/:company_id', to: 'bookkeeper#categorization'
        post 'categorize_batch', to: 'bookkeeper#categorize_batch'
        get 'vendors/:company_id', to: 'bookkeeper#vendors'
        get 'month_end/:company_id', to: 'bookkeeper#month_end'
        patch 'month_end/:company_id/check', to: 'bookkeeper#month_end_check'
        post 'month_end/:company_id/close', to: 'bookkeeper#month_end_close'
      end

      # Public invitation endpoints
      get 'invitations/:token', to: 'invitations#show'
      post 'invitations/:token/accept', to: 'invitations#accept'

      # API Keys
      resources :api_keys, only: [:index, :create, :destroy]

      # Dashboard
      get 'dashboard', to: 'dashboard#show'

      resources :companies, only: [:index, :show] do
        resources :accounts, only: [:index, :create, :update, :destroy]
        resources :transactions, only: [:index, :create, :update, :destroy] do
          collection do
            post :categorize
          end
        end
        resources :chart_of_accounts, only: [:index, :create, :update, :destroy] do
          collection do
            post :suggest
          end
        end
        resources :categorization_rules, only: [:index, :create, :update, :destroy] do
          collection do
            post :run
            get :suggestions
            post :ai_suggestions
          end
        end
        
        # Chat
        get 'chat', to: 'chat#index'
        post 'chat', to: 'chat#create'
        delete 'chat', to: 'chat#destroy'

        # Usage / billing
        get 'usage', to: 'usage#show'
        get 'usage/queries', to: 'usage#queries'
        get 'usage/history', to: 'usage#history'

        # Data import
        post 'imports/upload', to: 'imports#upload'
        post 'imports/commit', to: 'imports#commit'
        get 'imports/supported', to: 'imports#supported'
        post 'imports/suggest_category', to: 'imports#suggest_category'

        # Box.com integration
        get 'box/config', to: 'box#config'
        put 'box/config', to: 'box#update_config'
        post 'box/sync', to: 'box#sync'
        get 'box/sync_status', to: 'box#sync_status'
        get 'box/files', to: 'box#files'
        get 'box/embed_url/:file_id', to: 'box#embed_url'

        # Statement uploads
        resources :statements, only: [:index] do
          collection do
            post :upload
          end
          member do
            post :import
            get :preview
          end
        end

        # Agent (AI-driven statement processing)
        post 'agent/process_statement', to: 'agent#process_statement'
        get 'agent/accounts', to: 'agent#accounts'
        get 'agent/status', to: 'agent#status'

        # Reconciliation
        resources :reconciliations, only: [:index, :show, :create] do
          member do
            patch :toggle
            patch :suggest
            patch :finish
          end
        end

        # Receipts
        resources :receipts, only: [:index, :create] do
          member do
            patch :match
          end
        end

        # Invitations
        resources :invitations, only: [:index, :create, :destroy]

        # Notifications
        resources :notifications, only: [:index] do
          member do
            patch :mark_read
          end
          collection do
            post :read_all
          end
        end

        # Audit logs
        resources :audit_logs, only: [:index]

        # Journal entries
        resources :journal_entries, only: [:index, :show, :create, :update, :destroy] do
          member do
            post :post_entry
            post :reverse
          end
          collection do
            get :suggestions
            post :auto_adjust
            post :create_from_suggestion
            get :recurring_index
            post :create_recurring
            post :process_recurring
            get :templates
            post :from_template
          end
        end
        post 'journal_entries/recurring/:id/run', to: 'journal_entries#run_recurring'

        # Reports (all driven by general ledger / journal entries)
        get 'reports/profit_loss', to: 'reports#profit_loss'
        get 'reports/balance_sheet', to: 'reports#balance_sheet'
        get 'reports/general_ledger', to: 'reports#general_ledger'
        get 'reports/trial_balance', to: 'reports#trial_balance'
        get 'reports/account_transactions', to: 'reports#account_transactions'
        get 'reports/tax_form', to: 'reports#tax_form'
        post 'reports/nl_query', to: 'reports#nl_query'
        get 'reports/month_end_checklist', to: 'reports#month_end_checklist'

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
  get '/billing', to: 'home#index'
  get '/bookkeeper', to: 'home#index'
  get '/reconciliation', to: 'home#index'
  get '/receipts', to: 'home#index'
  get '/import', to: 'home#index'
  get '/journal', to: 'home#index'
  get '/onboarding', to: 'home#index'
  get '/chat', to: 'home#index'
  get '/login', to: 'home#index'
  get '/admin', to: 'home#index'
  get '/admin/billing', to: 'home#index'
  get '/admin/*path', to: 'home#index'
  get '/invite/:token', to: 'home#index'
end
