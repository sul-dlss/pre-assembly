source 'https://rubygems.org'

gem 'actionmailer'
gem 'actionpack', '~> 5.0', '>= 5.0.0.1'
gem 'nokogiri'
gem 'rake'
gem 'retries'
gem 'roo' # for processing spreadsheets
gem 'ruby-prof'
gem 'honeybadger', '~> 3.1'

# Stanford gems
gem 'assembly-image'
gem 'assembly-objectfile', '> 1.6.6'
gem 'assembly-utils'
# gem 'dor-fetcher'   # not supported anymore; only used by devel/get_dor_and_sdr_versions.rb script, which is not regularly used
gem 'dor-services', '< 6'
gem 'druid-tools'
gem 'harvestdor'
gem 'modsulator'
gem 'stanford-mods'
gem 'rails', '~> 5.2', '>= 5.2.1'
gem 'sqlite3'
gem 'turbolinks'

gem 'resque', '~> 1.27'
gem 'resque-lock'
gem 'resque-pool'
gem 'config'

group :test do
  gem 'equivalent-xml'
  gem 'solr_wrapper'
  gem 'jettywrapper'
  gem 'coveralls', require: false
end

group :deployment do
  gem 'capistrano', "~> 3"
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
