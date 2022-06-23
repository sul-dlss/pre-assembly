# frozen_string_literal: true

require 'resque/server'
Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  devise_for :users, skip: :all
  root to: 'batch_contexts#new'
  resources :batch_contexts, only: %i[create index new show]
  resources :job_runs, only: [:create, :index, :show]
  get 'job_runs/:id/download_log', to: 'job_runs#download_log', as: 'download_log'
  get 'job_runs/:id/download_report', to: 'job_runs#download_report', as: 'download_report'
  get 'job_runs/:id/discovery_report_summary', to: 'job_runs#discovery_report_summary', as: 'discovery_report_summary'
  mount Resque::Server.new, at: '/resque'
end
