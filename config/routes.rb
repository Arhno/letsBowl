Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :game_extracts, only: [ :create ]
    end
  end
end
