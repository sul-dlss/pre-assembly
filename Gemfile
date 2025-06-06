source 'https://rubygems.org'

gem 'bunny', '~> 2.17' # RabbitMQ library
gem 'config'
gem 'cssbundling-rails', '~> 1.2'
gem 'csv'
gem 'devise'
gem 'devise-remote-user'
gem 'globus_client', '~> 0.16'
gem 'honeybadger'
gem 'importmap-rails', '~> 1.2'
gem 'jbuilder'
gem 'kaminari' # pagination
gem 'nokogiri'
gem 'okcomputer'
gem 'pg' # postgres database
gem 'propshaft' # The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'pry' # make it possible to use pry for IRB
gem 'rails', '~> 8.0.0'
gem 'rake'
gem 'sidekiq', '~> 7.0'
gem 'simple_form' # rails form that handles errors internally and easily integrated w/ Bootstrap
gem 'sneakers', '~> 2.11' # rabbitMQ background processing
gem 'state_machines-activerecord'
gem 'stimulus-rails'
gem 'turbo-rails', '~> 1.1'
gem 'whenever', require: false

# Stanford gems
gem 'assembly-objectfile', '~> 2.1'
gem 'dor-services-client', '~> 15.1'
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
