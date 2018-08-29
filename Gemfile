source 'https://rubygems.org'

gem 'nokogiri'
gem 'rake'
gem 'retries'
gem 'roo' # for processing spreadsheets
gem 'ruby-prof'
gem 'honeybadger', '~> 3.1'

gem 'rails', '~> 5.2', '>= 5.2.1'
gem 'sqlite3'
gem 'turbolinks'

gem 'resque', '~> 1.27'
gem 'resque-lock'
gem 'resque-pool'
gem 'config'

# Stanford gems
gem 'assembly-image'
gem 'assembly-objectfile', '> 1.6.6' # use latest assembly-objectfile
gem 'assembly-utils'
gem 'dor-services', '< 6'
gem 'modsulator'

group :test do
  gem 'equivalent-xml'
  gem 'coveralls', require: false
  # gem 'solr_wrapper' # for running integration structure locally
  # gem 'jettywrapper' # for running integration structure locally
end

group :deployment do
  gem 'capistrano-bundler'
  gem 'capistrano-rvm'
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
