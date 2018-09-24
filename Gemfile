source 'https://rubygems.org'

gem 'bootstrap', '~> 4.1.3'
gem 'config'
gem 'devise'
gem 'devise-remote-user'
gem 'erubis' # implicit dependency for (old) rdf-rdfa, no longer default in Rails 5.1+
gem 'honeybadger', '~> 3.1'
gem 'jbuilder'
gem 'jquery-rails'
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
gem 'ruby-prof'
gem 'sqlite3'
gem 'turbolinks' # improves speed of following links in web application
gem 'uglifier' # compressor for JavaScript assets
gem "simple_form" # rails form that handles errors internally and easily integrated w/ Bootstrap
gem 'kaminari' # pagination

# Stanford gems
gem 'assembly-image'
gem 'assembly-objectfile', '~> 1.7'
gem 'dor-services', '~> 5.29'
gem 'modsulator'

group :test do
  gem 'coveralls', require: false
  gem 'equivalent-xml'
  gem 'factory_bot_rails'
  gem 'shoulda-matchers', git: 'https://github.com/thoughtbot/shoulda-matchers.git', branch: 'rails-5'
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'capistrano-passenger'
  gem 'capistrano-rails'
  gem 'dlss-capistrano', '~> 3.1'
end

group :development do
  gem 'listen'
end

group :development, :test do
  gem 'pry-byebug'
  gem 'rspec-rails', '~> 3.7'
  gem 'rails-controller-testing'
  gem 'rubocop', '~> 0.58'
  gem 'rubocop-rspec'
end
