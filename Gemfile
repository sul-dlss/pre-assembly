source 'https://rubygems.org'

gem "bunny", "~> 2.17" # RabbitMQ library
gem 'config'
gem 'devise'
gem 'devise-remote-user'
gem 'honeybadger', '~> 4.5'
gem 'jbuilder'
gem 'kaminari' # pagination
gem 'nokogiri'
gem 'okcomputer'
gem 'pg' # postgres database
gem 'propshaft' # The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'pry' # make it possible to use pry for IRB
gem 'rails', '~> 7.0'
gem 'rake'
gem 'sidekiq', '~> 7.0'
gem 'simple_form' # rails form that handles errors internally and easily integrated w/ Bootstrap
gem "sneakers", "~> 2.11" # rabbitMQ background processing
gem 'state_machines-activerecord'
gem "turbo-rails", "~> 1.1"

# Stanford gems
gem 'assembly-objectfile', '~> 2.1'
gem 'dor-services-client', '~> 12.0'
gem 'dor-workflow-client', '~> 6.0'
gem 'druid-tools'

group :test do
  gem 'capybara'
  gem 'equivalent-xml'
  gem 'factory_bot_rails'
  gem 'rails-controller-testing'
  gem 'random-word'
  gem 'rspec_junit_formatter'
  gem 'rspec-rails', '~> 5'
  gem 'shoulda-matchers', '~> 4.1'
  gem 'simplecov'
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'capistrano-passenger'
  gem 'capistrano-rails'
  gem 'capistrano-rvm', require: false # for ubuntu
  gem 'dlss-capistrano', require: false
end

group :development do
  gem 'listen'
end

group :development, :test do
  gem 'pry-byebug'
  gem 'puma', '~> 5.6'
  gem 'rubocop', '~> 1.25'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
end
