Rails.application.routes.draw do
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

    # Town-scoped search
    get "search", to: "search#show"
    get "search/quick", to: "search#quick"
  end

  # Global search (across all towns)
  get "search", to: "search#show", as: :global_search
  get "search/quick", to: "search#quick", as: :global_search_quick

  # Admin routes (global)
  namespace :admin do
    resources :api_costs, only: [ :index ]
    post "people/merge", to: "people#merge", as: :people_merge
    post "people/unmerge", to: "people#unmerge", as: :people_unmerge
  end

  # Root redirects to towns index
  root "towns#index"
end
