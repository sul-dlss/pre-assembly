# Initial deployment.
#
# 1) Setup directory structure on remote VM.
#
#    $ cap ENVIRONMENT deploy:setup
#
# 2) Manually copy files to $application/shared.
# 
#       - environment-specific configuration to config/environments.  
#       - certs to config/certs.
#
#
# 3) $ cap ENVIRONMENT deploy:update
#
# Subsequent deployments:
#
#   $ cap ENVIRONMENT deploy
#
#
# ENVIRONMENT can be:
#  * testing
#  * development
#  * production

load 'deploy'
require 'dlss/capistrano/robots'
require 'rvm/capistrano'

set :application,     'pre-assembly'
set :git_subdir,      "lyberteam/#{application}.git"
set :rvm_ruby_string, "1.9.3"

set :shared_children, %w(
  log
  config/certs
  config/environments
)

set :branch do
  last_tag = `git describe --abbrev=0 --tags`.strip
  default_tag = 'master'
  
  tag = Capistrano::CLI.ui.ask "Tag to deploy (make sure to push the tag first): [default: #{default_tag}, last tag: #{last_tag}] "
  tag = default_tag if tag.empty?
  tag
end

task :development do
  role :app, 'sul-lyberservices-dev.stanford.edu'
  set :deploy_env, 'development'
  set :rails_env,  'development'  # TEMPORARY: needed until lyberteam-gems-devel is fixed.
  set :bundle_without, []         # Deploy all gem groups on the dev VM.
end

task :argo do
  role :app, 'argo.stanford.edu'
  set :deploy_env, 'production'
  set :rails_env,  'production'  # TEMPORARY: needed until lyberteam-gems-devel is fixed.
end

task :testing do
  role :app, 'sul-lyberservices-test.stanford.edu'
  set :deploy_env, 'test'
  set :rails_env,  'test'  # TEMPORARY: see above
end

task :production do
  role :app, 'sul-lyberservices-prod.stanford.edu'
  set :deploy_env, 'production'
  set :rails_env,  'production' # TEMPORARY: see above
end

namespace :dlss do
  task :set_shared_children do
    # no-op
  end
end

after "deploy", "rvm:trust_rvmrc"
namespace :rvm do
  task :trust_rvmrc do
    run "rvm rvmrc trust #{release_path}"
  end
end

after "deploy:update", "deploy:cleanup" 

set :sunet_id,   Capistrano::CLI.ui.ask('SUNetID: ') { |q| q.default =  `whoami`.chomp }
set :rvm_type,   :system
set :user,       'lyberadmin' 
set :repository, "ssh://#{sunet_id}@corn.stanford.edu/afs/ir/dev/dlss/git/#{git_subdir}"
set :deploy_to,  "/home/#{user}/#{application}"
set :deploy_via, :copy
set :shared_config_certs_dir, true