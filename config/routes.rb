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
        resources :households, only: [:index, :create, :update, :destroy] do
          member do
            get :members
            post :members, action: :add_member
            put 'members/:user_id', action: :update_member
            delete 'members/:user_id', action: :remove_member
          end
        end
        resources :accounts, only: [:index, :create, :update, :destroy]
      end

      resources :households, only: [:index, :show] do
        resources :accounts, only: [:index, :create, :update, :destroy]
        resources :transactions, only: [:index, :create, :update, :destroy]
        resources :chart_of_accounts, only: [:index, :create, :update, :destroy]
        
        # Reports
        get 'reports/profit_loss', to: 'reports#profit_loss'
        get 'reports/balance_sheet', to: 'reports#balance_sheet'
      end
    end
  end

  # Vue router handles these client-side routes
  get '/dashboard', to: 'home#index'
  get '/reports', to: 'home#index'
  get '/chart-of-accounts', to: 'home#index'
  get '/transactions', to: 'home#index'
  get '/login', to: 'home#index'
  get '/admin/*path', to: 'home#index'
end
