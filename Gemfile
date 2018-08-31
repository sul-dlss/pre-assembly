source 'https://rubygems.org'

gem 'config'
gem 'honeybadger', '~> 3.1'
gem 'nokogiri'
gem 'rails', '~> 5.2', '>= 5.2.1'
gem 'rake'
gem 'resque', '~> 1.27' # needs to match redis on VM
gem 'resque-lock'
gem 'resque-pool'
gem 'retries'
gem 'roo' # for processing spreadsheets
gem 'ruby-prof'
gem 'sqlite3'
gem 'turbolinks'

# Stanford gems
gem 'assembly-image'
gem 'assembly-objectfile', '~> 1.7'
gem 'assembly-utils'
gem 'dor-services', '~> 5.29'
gem 'modsulator'

group :test do
  gem 'coveralls', require: false
  gem 'equivalent-xml'
  # gem 'solr_wrapper' # for running integration structure locally
  # gem 'jettywrapper' # for running integration structure locally
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
  gem 'byebug'
  gem 'rspec-rails', '~> 3.7'
  gem 'rubocop', '~> 0.58'
  gem 'rubocop-rspec'
end
