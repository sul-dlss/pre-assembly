source 'https://rubygems.org'

# Let's require at least ruby 1.9, but allow ruby 2.0 too
ruby "1.9.3" if RUBY_VERSION < "1.9"

gem 'nokogiri'
gem 'equivalent-xml'
gem 'csv-mapper'
gem 'dor-services', '>=4.12.2'
gem 'druid-tools', '>=0.2.0'
gem 'lyber-core'
gem 'rest-client'
gem 'rake'
gem 'addressable', '<= 2.3.5'
gem 'rdf', '<= 1.0.9'
gem 'assembly-objectfile'
gem 'assembly-image', '>= 1.6.1'
gem 'assembly-utils', '>= 1.3.0'
gem 'dir_validator'
gem 'dor-workflow-service', '>= 1.3.1'
gem 'actionpack', '>= 3.2.19'
gem 'actionmailer', '>= 3.2.19'
gem 'revs-utils', '>= 1.0.7'
gem 'harvestdor'
gem 'dor-fetcher', '>= 1.1.5'

group :test do
  gem 'yard'
  gem 'rspec', '~> 2.6'
end

group :deployment do
	gem 'capistrano', "~> 3"
  gem 'capistrano-bundler'
  gem 'lyberteam-capistrano-devel', '~> 3'
  gem 'capistrano-rvm'
end

group :development do
  gem 'awesome_print'
end