source 'https://rubygems.org'

gem 'actionmailer', '~> 4.2.10'
gem 'actionpack', '~> 4.2.10'
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
gem 'dor-services-client'
gem 'druid-tools'
gem 'harvestdor'
gem 'modsulator'
gem 'revs-utils', '~> 2.1.24'
gem 'stanford-mods'

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
  gem 'awesome_print'
end

group :development, :test do
  gem 'byebug'
end
