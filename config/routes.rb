# frozen_string_literal: true

Rails.application.routes.draw do
  require 'sidekiq/web'
  mount Sidekiq::Web => '/queues'

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  devise_for :users, skip: :all
  root to: 'batch_contexts#new'
  resources :batch_contexts, only: %i[create index new show]
  resources :job_runs, only: [:create, :index, :show] do
    member do
      get :download_log
      get :download_report
      get :discovery_report_summary
      get :progress_log
      get :process_log
    end
  end
  resources :globus, only: [:show, :index, :create]
end
