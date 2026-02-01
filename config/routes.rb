Rails.application.routes.draw do
  root 'home#index'

  # API routes
  namespace :api do
    namespace :v1 do
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
  get '/reports', to: 'home#index'
  get '/chart-of-accounts', to: 'home#index'
  get '/transactions', to: 'home#index'
end
