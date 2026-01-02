Rails.application.routes.draw do
  # Development email preview at /letter_opener
  if Rails.env.development?
    require "letter_opener_web"
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  devise_for :users, controllers: {
    sessions: "users/sessions",
    magic_links: "users/magic_links"
  }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Towns index (home page)
  resources :towns, only: [ :index, :show ], param: :slug do
    # Town-scoped resources
    resources :documents, only: [ :index, :show ] do
      member do
        post :retry
      end
    end

    resources :governing_bodies, only: [ :index, :show ]
    resources :people, only: [ :index, :show ]
    resources :topics, only: [ :index ]

    # Town-scoped search
    get "search", to: "search#show"
    get "search/quick", to: "search#quick"
  end

  # Global search (across all towns)
  get "search", to: "search#show", as: :global_search
  get "search/quick", to: "search#quick", as: :global_search_quick

  # Admin routes (global)
  namespace :admin do
    root to: "dashboard#index"
    resources :users, except: [ :show ] do
      member do
        post :send_magic_link
      end
    end
    resources :api_costs, only: [ :index ]

    resources :documents, only: [ :index, :create, :show, :update, :destroy ] do
      member do
        post :reextract
        post :approve
        post :reject
      end
      collection do
        post :bulk_retry
        post :bulk_approve
      end
    end

    resources :people, only: [ :index ] do
      collection do
        get :duplicates
        post :merge
        post :unmerge
        post :recompute_duplicates
      end
    end

    # Audit logs - default to admin logs
    get "audit_logs", to: redirect("/admin/audit_logs/admin")
    get "audit_logs/admin", to: "audit_logs#admin_logs", as: :admin_logs
    get "audit_logs/authentication", to: "audit_logs#authentication_logs", as: :authentication_logs
    get "audit_logs/documents", to: "audit_logs#document_events", as: :document_events

    # System dashboard
    resources :system, only: [ :index ] do
      collection do
        post :rebuild_search
        post :clear_cache
      end
    end
  end

  # Root redirects to towns index
  root "towns#index"
end
