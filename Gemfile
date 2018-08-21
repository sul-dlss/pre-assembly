source 'https://rubygems.org'

gem 'actionmailer'
gem 'actionpack', '~> 5.0', '>= 5.0.0.1'
gem 'csv-mapper'
gem 'equivalent-xml'
gem 'nokogiri'
gem 'rake'
gem 'rdf'
gem 'rest-client'
gem 'retries'
gem 'roo'
gem 'ruby-prof'
gem 'honeybadger', '~> 3.1'

# Stanford gems
gem 'assembly-image'
gem 'assembly-objectfile', '> 1.6.6'
gem 'assembly-utils'
gem 'dir_validator'
# gem 'dor-fetcher'   # not supported anymore; only used by devel/get_dor_and_sdr_versions.rb script, which is not regularly used
gem 'dor-services', '< 6'
gem 'druid-tools'
gem 'harvestdor'
gem 'modsulator'
gem 'stanford-mods'
gem 'rails', '~> 5.2', '>= 5.2.1'
gem 'sqlite3'
gem 'turbolinks'

group :test do
  gem 'rspec', '~> 3.0'
  gem 'yard'
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
  gem 'rubocop', '~> 0.58'
  gem 'rubocop-rspec'
end
