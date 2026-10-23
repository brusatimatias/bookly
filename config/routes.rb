Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # A business's public pages, on its subdomain (barberia-centro.<app host>).
  # From other hosts, link to them with public_url_options(business).
  constraints(->(request) { Business.subdomain?(request.subdomain) }) do
    get "/", to: "businesses#show", as: :business
    get "book", to: "bookings#new", as: :new_booking
    post "book", to: "bookings#create", as: :bookings
    # The customer's appointment, by its management token (no account).
    resources :appointments, param: :token, only: :show do
      scope module: :appointments do
        resource :cancellation, only: %i[new create]
        resource :reschedule, only: %i[new create]
      end
    end
  end

  # Everything else, on the app's own domain (with or without www), so the
  # session cookie lives on a single host.
  constraints(->(request) { request.subdomain.in?([ "", "www" ]) }) do
    root "home#show"

    resource :session, only: %i[ new create destroy ]
    resources :passwords, param: :token, only: %i[ new create edit update ]
    resource :locale, only: :update
    resource :dashboard, only: :show
    resources :invitations, param: :token, only: %i[ show update ]
    get "signup", to: "signups#new", as: :new_signup
    post "signup", to: "signups#create", as: :signup

    # The platform panel, for Bookly's own team (User#platform_admin).
    namespace :platform do
      root "businesses#index"
      resources :businesses, only: %i[index show] do
        member do
          patch :suspend
          patch :reactivate
        end
      end
    end

    mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

    # A business's panel, for its members only. Keep this scope last so it
    # never shadows app routes; new top-level paths must also be added to
    # Business::RESERVED_SLUGS.
    scope ":business_slug", constraints: { business_slug: Business::SLUG_FORMAT } do
      namespace :admin do
        root "dashboards#show"

        resource :team, only: :show
        resource :business, only: %i[edit update]
        # The setup assistant: /setup opens the step to do next.
        get "setup", to: "setups#show", as: :setup
        get "setup/:step", to: "setups#show", as: :setup_step, constraints: { step: Regexp.union(BusinessSetup::STEPS) }
        patch "setup/:step", to: "setups#update", constraints: { step: Regexp.union(BusinessSetup::STEPS - [ "done" ]) }
        resource :settings, only: %i[edit update]
        resource :branding, only: %i[edit update]
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
        resource :availability, only: :show
        resources :requests, only: :index
        resource :agenda, only: :show
        resource :statistics, only: :show
        resources :appointments, only: :show do
          member do
            patch :confirm
            patch :attended
            patch :no_show
          end
          resource :rejection, only: %i[new create]
          resource :cancellation, only: %i[new create]
          resource :reschedule, only: %i[new create]
          resource :reassignment, only: %i[new create]
        end
      end

      # The public pages' old paths, from before subdomains (emails already
      # sent link to them): moved permanently to the same page, with the same
      # query, on the business's subdomain. Reserved slugs aren't redirected.
      to_subdomain = redirect do |params, request|
        rest = request.fullpath.delete_prefix("/#{params[:business_slug]}")
        rest = "/#{rest}" unless rest.start_with?("/")
        "#{request.protocol}#{params[:business_slug]}.#{request.domain}#{request.port_string}#{rest}"
      end
      %w[/ book appointments/:token appointments/:token/cancellation/new appointments/:token/reschedule/new].each do |path|
        get path, to: to_subdomain, as: nil, constraints: ->(request) { Business.subdomain?(request.path_parameters[:business_slug]) }
      end
    end
  end
end
