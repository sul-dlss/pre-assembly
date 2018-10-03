require 'resque/server'
Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  devise_for :users, skip: :all
  root to: 'bundle_contexts#new'
  resources :bundle_contexts, only: [:create, :new, :show]
  resources :job_runs, only: [:create, :index, :show]
  get 'job_runs/:id/download', to: 'job_runs#download', as: 'download'
  mount Resque::Server.new, at: '/resque'
end
