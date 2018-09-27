require  'resque/server'
Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  devise_for :users, skip: :all
  root to: "bundle_contexts#new"
  resources :bundle_contexts, only: [:new, :create]
  resources :job_runs, only: [:show, :index]
  get 'job_runs/:id/download', to: 'job_runs#download', as: 'download'
  mount Resque::Server.new, at: '/resque'
end
