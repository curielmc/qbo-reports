Rails.application.routes.draw do
  # ActiveAdmin
  ActiveAdmin.routes(self)
  
  # Devise for admin users
  devise_for :admin_users, ActiveAdmin::Devise.config
  
  # Devise for regular users
  devise_for :users

  root 'home#index'

  # API routes
  namespace :api do
    namespace :v1 do
      # Auth endpoints
      post 'auth/login', to: 'sessions#create'
      delete 'auth/logout', to: 'sessions#destroy'
      get 'auth/me', to: 'sessions#show'

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
end
