source 'https://rubygems.org'

gem 'bootstrap', '~> 4.1.3'
gem 'config'
gem 'devise'
gem 'devise-remote-user'
gem 'honeybadger', '~> 3.1'
gem 'jbuilder'
gem 'jquery-rails'
gem 'kaminari' # pagination
gem 'nokogiri'
gem 'okcomputer'
gem 'pg' # postgres database
gem 'rails', '~> 5.2', '>= 5.2.1'
gem 'rake'
gem 'resque', '~> 1.27' # needs to match redis on VM
gem 'resque-lock'
gem 'resque-pool'
gem 'retries'
gem 'roo' # for processing spreadsheets
gem 'simple_form' # rails form that handles errors internally and easily integrated w/ Bootstrap
gem 'turbolinks' # improves speed of following links in web application
gem 'uglifier' # compressor for JavaScript assets

# Stanford gems
gem 'assembly-image', '~> 1.7'
gem 'assembly-objectfile', '~> 1.7'
gem 'dor-services', '~> 6.1'
gem 'dor-services-client', '~> 1.0'

group :test do
  gem 'coveralls', require: false
  gem 'equivalent-xml'
  gem 'factory_bot_rails'
  gem 'shoulda-matchers', '~> 4.0.0.rc1'
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'capistrano-passenger'
  gem 'capistrano-rails'
  gem 'capistrano-resque-pool'
  gem 'dlss-capistrano', '~> 3.1'
end

group :development do
  gem 'listen'
end

group :development, :test do
  gem 'pry-byebug'
  gem 'rspec-rails', '~> 3.7'
  gem 'rails-controller-testing'
  gem 'rubocop', '~> 0.60.0'
  gem 'rubocop-rspec'
  gem 'ruby-prof'
  gem 'sqlite3'
end
