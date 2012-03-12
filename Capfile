# Initial setup run from laptop
# 1) Setup directory structure on remote VM
#   $ cap dev deploy:setup
# 2) Manually copy environment specific config file to $application/shared/config/environments.  
#      Only necessary for initial install
# 3) Manually copy certs to $application/shared/config/certs
#      Only necessary for initial install
# 4) Copy project from source control to remote
#   $ cap dev deploy:update
# 5) Start robots on remote host
#   $ cap dev deploy:start
#
# Future releases will stop the robots, update the code, then start the robots 
#   $ cap dev deploy
# If you only want to stop the robots, update the code, and NOT start the robots
#   $ cap dev deploy:update
#   You can then manually start the robots on your own
#      $ cap dev deploy:start

load 'deploy' if respond_to?(:namespace) # cap2 differentiator
require 'dlss/capistrano/robots'

set :application, 'pre-assembly'

task :dev do
  role :app, 'sul-lyberservices-dev.stanford.edu'
  set :bundle_without, []         # deploy all gem groups on the dev VM.
  set :deploy_env, 'development'
end

task :testing do
  role :app, 'sul-lyberservices-test.stanford.edu'
  set :deploy_env, 'test'
end

task :production do
  role :app, 'sul-lyberservices-prod.stanford.edu'
  set :deploy_env, 'production'
end

set :sunet_id, Capistrano::CLI.ui.ask('SUNetID: ')
set :user, 'lyberadmin' 
set :repository,  '/afs/ir/dev/dlss/git/lyberteam/common-accessioning.git'
set :local_repository, "ssh://#{sunet_id}@corn.stanford.edu#{repository}"
set :deploy_to, "/home/#{user}/#{application}"

set :shared_config_certs_dir, true
