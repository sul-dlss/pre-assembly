source 'https://rubygems.org'

gem 'bunny' # RabbitMQ library
gem 'cocina-models'
gem 'config'
gem 'cssbundling-rails'
gem 'csv'
gem 'devise'
gem 'devise-remote-user'
gem 'globus_client'
gem 'honeybadger'
gem 'importmap-rails'
gem 'jbuilder'
gem 'kaminari' # pagination
gem 'nokogiri'
gem 'okcomputer'
gem 'pg' # postgres database
gem 'propshaft' # The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'rails', '~> 8.1.0'
gem 'rake'
gem 'sidekiq'
gem 'simple_form' # rails form that handles errors internally and easily integrated w/ Bootstrap
gem 'sneakers' # rabbitMQ background processing
gem 'state_machines-activerecord'
gem 'stimulus-rails'
gem 'turbo-rails'
gem 'whenever', require: false

# Stanford gems
gem 'assembly-objectfile'
gem 'dor-services-client'
gem 'druid-tools'

group :test do
  gem 'capybara'
  gem 'equivalent-xml'
  # NOTE: factory_bot_rails >= 6.3.0 requires env/test.rb to have config.factory_bot.reject_primary_key_attributes = false
  gem 'axe-core-rspec'
  gem 'factory_bot_rails'
  gem 'rails-controller-testing'
  gem 'random-word'
  gem 'rspec_junit_formatter'
  gem 'rspec-rails'
  gem 'selenium-webdriver'
  gem 'shoulda-matchers'
  gem 'simplecov'
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'capistrano-passenger'
  gem 'capistrano-rails'
  gem 'dlss-capistrano', require: false
end

group :development do
  gem 'listen'
end

group :development, :test do
  # Security audit for known security defects in code (use config/brakeman.ignore to ignore issues)
  gem 'brakeman', require: false
  gem 'debug'
  gem 'erb_lint', require: false
  gem 'puma'
  gem 'rubocop'
  gem 'rubocop-capybara'
  gem 'rubocop-factory_bot'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'rubocop-rspec_rails'
end
