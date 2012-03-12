# Initial deployment.
#
# 1) Setup directory structure on remote VM.
#
#    $ cap dev deploy:setup
#
# 2) Manually copy files to $application/shared.
# 
#       - environment-specific configuration to config/environments.  
#       - certs to config/certs.
#
# Subsequent deployments:
#
#   # Stop robots, deploy code, start robots.
#   $ cap dev deploy
#
#   # Stop robots, deploy code.
#   $ cap dev deploy:update
#
#   # Start robots.
#   $ cap dev deploy:start

load 'deploy' if respond_to?(:namespace) # cap2 differentiator
require 'dlss/capistrano/robots'

set :application, 'pre-assembly'

task :dev do
  role :app, 'lyberservices-dev.stanford.edu'
  set :bundle_without, []         # deploy all gem groups on the dev VM.
  set :deploy_env, 'development'
end

task :testing do
  role :app, 'lyberservices-test.stanford.edu'
  set :deploy_env, 'test'
end

task :production do
  role :app, 'lyberservices-prod.stanford.edu'
  set :deploy_env, 'production'
end

set :sunet_id, Capistrano::CLI.ui.ask('SUNetID: ') { |q| q.default =  `whoami`.chomp }
set :rvm_type, :user
set :user, 'lyberadmin' 
set :repository,  '/afs/ir/dev/dlss/git/lyberteam/common-accessioning.git'
set :local_repository, "ssh://#{sunet_id}@corn.stanford.edu#{repository}"
set :deploy_to, "/home/#{user}/#{application}"

set :shared_config_certs_dir, true
