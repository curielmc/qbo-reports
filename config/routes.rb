Rails.application.routes.draw do
  root 'home#index'

  # Vue router handles these client-side routes
  get '/reports', to: 'home#index'
  get '/chart-of-accounts', to: 'home#index'
  get '/transactions', to: 'home#index'
end
