source 'https://rubygems.org'

gem 'actionmailer', '< 5'
gem 'actionpack', '< 5'
gem 'csv-mapper'
gem 'equivalent-xml'
gem 'nokogiri'
gem 'rake'
gem 'rdf'
gem 'rest-client'
gem 'roo'
gem 'ruby-prof'

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
gem 'revs-utils', '~> 2.1.23'
gem 'stanford-mods'

group :test do
  gem 'rspec', '~> 3.0'
  gem 'yard'
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
