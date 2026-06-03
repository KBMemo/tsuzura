Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope module: :web, as: :web do
    root to: "albums#index"
    resources :albums, only: %i[index show new create], param: :id do
      member do
        post :upload
      end
    end
    resources :media, only: %i[edit update], param: :id do
      member do
        get :preview
      end
    end
  end

  scope module: :api do
    namespace :v1 do
      resources :albums, only: %i[index create show], param: :id
      post "media/batch", to: "media#batch"
      get "media/lookup", to: "media#lookup", as: :media_lookup
      get "media/:id", to: "media#show", as: :media
      patch "media/:id/edits", to: "media#update_edits", as: :media_edits
      get "media/:id/web", to: "media#web", as: :media_web
    end
  end

  namespace :internal do
    get "albums", to: "albums#index"
    get "albums/:id", to: "albums#show", as: :album
  end
end
