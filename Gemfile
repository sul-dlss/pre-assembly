source 'https://rubygems.org'

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
gem 'pry-rails' # useful for rails console
gem 'rails', '~> 7.0'
gem 'rake'
gem 'redis', '~> 4.0' # redis 5.x has breaking changes with resque, see https://github.com/resque/resque/issues/1821
gem 'sidekiq', '~> 6.4'
gem 'simple_form' # rails form that handles errors internally and easily integrated w/ Bootstrap
gem 'state_machines-activerecord'

# Stanford gems
gem 'assembly-objectfile', '~> 2.1'
gem 'dor-services-client', '~> 12.0'
gem 'dor-workflow-client', '~> 5.0'
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

gem "turbo-rails", "~> 1.1"
