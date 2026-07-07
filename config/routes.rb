Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # Las tres vistas sobre `businesses` (SAD §4.2): tabla, ficha, kanban.
  resources :businesses, only: [ :index, :show ] do
    member do
      patch :pos_status # captura móvil de pos_status en 1 tap (ADR-004)
    end
    resources :contact_events, only: [ :create ]
  end

  # Kanban CRM (ADR-009): tablero + mover tarjeta (cambia pipeline_stage).
  get "kanban" => "kanban#index"
  patch "kanban/:id" => "kanban#update", as: :kanban_business

  root "businesses#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
