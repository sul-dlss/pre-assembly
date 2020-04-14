source 'https://rubygems.org'

gem 'bootstrap', '~> 4.3', '>= 4.3.1'
gem 'config'
gem 'devise'
gem 'devise-remote-user'
gem 'honeybadger', '~> 4.5'
gem 'jbuilder'
gem 'jquery-rails'
gem 'kaminari' # pagination
gem 'nokogiri'
gem 'okcomputer'
gem 'pg' # postgres database
gem 'pry-rails' # useful for rails console
gem 'rails', '~> 6.0'
gem 'rake'
gem 'resque', '~> 2.0' # needs to match redis on VM
gem 'resque-lock'
gem 'resque-pool'
gem 'sassc', '~> 2.0.1' # Pinning to 2.0 because 2.1 requires GLIBC 2.14 on deploy
gem 'simple_form' # rails form that handles errors internally and easily integrated w/ Bootstrap
gem 'turbolinks' # improves speed of following links in web application
gem 'uglifier' # compressor for JavaScript assets

# Stanford gems
gem 'assembly-image', '~> 1.7'
gem 'assembly-objectfile', '~> 1.9'
gem 'dor-services-client', '~> 5.0'
gem 'dor-workflow-client'
gem 'druid-tools'

group :test do
  gem 'capybara'
  gem 'coveralls', require: false
  gem 'equivalent-xml'
  gem 'factory_bot_rails'
  gem 'rails-controller-testing'
  gem 'random-word'
  gem 'rspec-rails', '~> 4.0'
  gem 'shoulda-matchers', '~> 4.1'
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
  gem 'rubocop', '~> 0.76.0'
  gem 'rubocop-rspec'
  # gem 'ruby-prof'
  gem 'sqlite3'
end
