Rails.application.routes.draw do
  namespace :api do
    resource :registration, only: :create, controller: "users" # POST /api/registration
    resource :session, only: [:create, :show, :destroy]                           # POST /api/session
    resource :password, only: [:create, :update]                                  # forgot / reset password
    resources :uploads, only: :create                                             # POST /api/uploads (editor images)
    # The logged-in user's own account (singular: no id in the URL, so only your own)
    resource :profile, only: [:update, :destroy] do                               # PATCH (rename) / DELETE (delete account)
      patch :password                                                             # PATCH /api/profile/password
      patch :email                                                                # PATCH /api/profile/email
      resource :avatar, only: [:update, :destroy]                                 # PUT / DELETE /api/profile/avatar
    end
    resources :users, only: :show                                                 # GET /api/users/:id (public profile)

    resources :articles, only: [:index, :show, :create, :update, :destroy] do
      resources :comments, only: [:create, :destroy]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
