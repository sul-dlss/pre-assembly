# Load DSL and Setup Up Stages
require 'capistrano/setup'

# Includes default deployment tasks
require 'capistrano/deploy'

require "capistrano/scm/git"
install_plugin Capistrano::SCM::Git

require 'capistrano/bundler'
require 'capistrano/honeybadger'
require 'capistrano/passenger'
require 'capistrano/rails'
require 'dlss/capistrano'
require 'dlss/capistrano/resque_pool'

# Loads custom tasks from `lib/capistrano/tasks' if you have any defined.
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }
