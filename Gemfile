source :rubygems
source 'http://sulair-rails-dev.stanford.edu'

gem 'nokogiri'
gem 'csv-mapper'
gem 'dor-services', '>=3.9.0'
gem 'druid-tools', '>=0.2.0'
gem 'lyber-core'
gem 'rest-client'
gem 'rake'
gem 'checksum-tools'
gem 'assembly-objectfile', '>= 1.2.6'
gem 'assembly-image', '>= 1.3.2'
gem 'assembly-utils', '>= 1.0.6'

group :test do
  gem 'equivalent-xml'
  gem 'rake'
  gem 'rspec', '~> 2.6'
end

group :development do
	gem 'lyberteam-devel', '<= 0.8.0'  # we need to stay on older versions for now until we can fix the deployment capistrano issues, 7/25/2012, Peter Mangiafico
	gem 'lyberteam-capistrano-devel', '<= 0.9.0'
  gem 'capistrano'
  gem 'awesome_print'
end
