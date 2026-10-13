Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "home#show"

  resource :session, only: %i[ new create destroy ]
  resources :passwords, param: :token, only: %i[ new create edit update ]
  resource :locale, only: :update
  resource :dashboard, only: :show
  resources :invitations, param: :token, only: %i[ show update ]

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Public business pages. Keep this scope last so it never shadows app routes;
  # new top-level paths must also be added to Business::RESERVED_SLUGS.
  scope ":business_slug", constraints: { business_slug: Business::SLUG_FORMAT } do
    get "/", to: "businesses#show", as: :business

    # Business panel, for its members only.
    namespace :admin do
      root "dashboards#show"

      resource :team, only: :show
      resource :settings, only: %i[edit update]
      resources :memberships, only: %i[update destroy]
      resources :invitations, only: %i[new create destroy] do
        post :resend, on: :member
      end
      resources :services, only: %i[index new create edit update] do
        member do
          patch :deactivate
          patch :reactivate
        end
      end
      resources :professionals, only: %i[index new create edit update] do
        member do
          patch :deactivate
          patch :reactivate
        end
        resource :schedule, only: %i[edit update]
      end
      resources :time_blocks, only: %i[index new create edit update destroy]
    end
  end
end
