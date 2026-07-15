Rails.application.routes.draw do
  devise_for :users,
    path: "",
    controllers: {
      passwords: "users/passwords",
      registrations: "users/registrations",
      sessions: "users/sessions"
    },
    path_names: {
      sign_in: "login",
      sign_out: "logout",
      sign_up: "register",
      password: "password",
      confirmation: "confirmation"
    }
  resource :dashboard, only: :show, controller: "dashboard"
  resource :profile, only: %i[edit update] do
    delete :avatar, action: :destroy_avatar
  end
  resources :links do
    get :export, on: :collection, action: :export_all
    member do
      get :export
      get :qr
    end
  end
  get "shorten", to: "public/links#new", as: :public_shortener
  post "shorten", to: "public/links#create"
  root "pages#home"
  get "terms", to: "pages#terms"
  get "privacy", to: "pages#privacy"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get ":slug", to: "redirects#show", as: :short_link
end
