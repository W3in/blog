Rails.application.routes.draw do
  namespace :api do
    resource :registration, only: :create, controller: "users" # POST /api/registration
    resource :session, only: [:create, :show, :destroy]                           # POST /api/session
    resource :password, only: [:create, :update]                                  # forgot / reset password

    resources :articles, only: [:index, :show, :create, :update, :destroy] do
      resources :comments, only: [:create, :destroy]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
