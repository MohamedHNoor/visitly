Rails.application.routes.draw do
  root "pages#home"

  get "up" => "rails/health#show", as: :rails_health_check

  get "login", to: "sessions#new", as: :new_session
  resource :session, only: %i[create destroy]
  get "register", to: "registrations#new", as: :new_registration
  resource :registration, only: :create
  get "verification/pending", to: "verifications#pending", as: :verification_pending
  resource :verification, only: %i[show create update]
  resources :passwords, only: %i[new create]
  resource :password, only: %i[edit update]
  get "onboarding", to: "onboarding#new", as: :new_onboarding
  post "onboarding", to: "onboarding#create", as: :onboarding
  get "setup-complete", to: "setup_completions#show", as: :setup_complete
  resources :invitations, only: %i[index create destroy] do
    post :resend, on: :member
  end
  resource :invitation_acceptance, only: %i[show create]
  resource :workspace, only: :show
end
