source 'https://rubygems.org'
source 'http://sul-gems.stanford.edu'


# Let's require at least ruby 1.9, but allow ruby 2.0 too
ruby "1.9.3" if RUBY_VERSION < "1.9"

gem 'nokogiri'
gem 'equivalent-xml'
gem 'csv-mapper'
gem 'dor-services', '>=4.0'
gem 'druid-tools', '>=0.2.0'
gem 'lyber-core'
gem 'rest-client'
gem 'rake'
gem 'addressable'
gem 'rdf', '<= 1.0.9'
gem 'assembly-objectfile'
gem 'assembly-image', '>= 1.6.1'
gem 'assembly-utils', '>= 1.3.0'
gem 'dir_validator'
gem 'dor-workflow-service', '>= 1.3.1'
gem 'actionpack', '>= 3.2.11'
gem 'actionmailer', '>= 3.2.11'
gem 'revs-utils', '>= 1.0.0'

group :test do
  gem 'yard'
  gem 'rspec', '~> 2.6'
end

group :development do
	gem 'lyberteam-capistrano-devel', '>= 1.1.0'
  gem 'capistrano', "< 3"
  gem 'rvm-capistrano'
  gem 'awesome_print'
  gem 'net-ssh-kerberos', :platform => :ruby_18
  gem 'net-ssh-krb', :platform => :ruby_19
  gem 'gssapi', :github => 'cbeer/gssapi'
end
