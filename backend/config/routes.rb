Rails.application.routes.draw do
  root "articles#index"
  
  namespace :api do
    resource :registration, only: :create, controller: "users" # POST /api/registration
    resource :session, only: [:create, :show, :destroy]                           # POST /api/session

    resources :articles, only: [:index, :show, :create, :update, :destroy] do
      resources :comments, only: [:create, :destroy]
    end
  end

  resources :articles do
    resources :comments
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
