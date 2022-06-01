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
gem 'pry-rails' # useful for rails console
gem 'rails', '~> 7.0'
gem 'rake'
gem 'resque', '~> 2.0' # needs to match redis on VM
gem 'resque-pool'
gem 'simple_form' # rails form that handles errors internally and easily integrated w/ Bootstrap
gem 'propshaft' # The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'state_machines-activerecord'

# Stanford gems
gem 'assembly-image', '~> 1.7'
gem 'assembly-objectfile', '~> 1.10', '>= 1.10.3' # webarchive-seed and reading order is supported in 1.10.2 and better
gem 'dor-services-client', '~> 12.0'
gem 'dor-workflow-client', '~> 4.0'
gem 'druid-tools'

group :test do
  gem 'capybara'
  gem 'simplecov'
  gem 'equivalent-xml'
  gem 'factory_bot_rails'
  gem 'rails-controller-testing'
  gem 'random-word'
  gem 'rspec-rails', '~> 5'
  gem 'rspec_junit_formatter'
  gem 'shoulda-matchers', '~> 4.1'
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
  gem 'puma', '~> 5.6'
  gem 'pry-byebug'
  gem 'rubocop'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  # gem 'ruby-prof'
  gem 'sqlite3'
end
