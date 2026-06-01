Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope module: :api do
    namespace :v1 do
      resources :albums, only: %i[index create show], param: :id
      post "media/batch", to: "media#batch"
      get "media/:id", to: "media#show", as: :media
      get "media/:id/web", to: "media#web", as: :media_web
    end
  end

  namespace :internal do
    get "albums/:id", to: "albums#show", as: :album
  end
end
