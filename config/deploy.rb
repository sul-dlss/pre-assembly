# frozen_string_literal: true

set :application, 'pre-assembly'
set :repo_url, 'ssh://git@github.com/sul-dlss/pre-assembly'

set :ssh_options,
    keys: [Capistrano::OneTimeKey.temporary_ssh_private_key_path],
    forward_agent: true,
    auth_methods: %w[publickey password]

# Default branch is :master
ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/opt/app/preassembly/pre-assembly'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
append :linked_files, 'config/master.key', 'config/honeybadger.yml', 'config/database.yml'

# Default value for linked_dirs is []
append :linked_dirs, 'log', 'config/certs', 'config/settings', 'tmp', 'vendor/bundle'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

# update shared_configs before restarting app
before 'deploy:restart', 'shared_configs:update'

# Resque pool
after 'deploy:restart', 'resque:pool:hot_swap'

set :honeybadger_env, fetch(:stage)

# Bundler 2 options
set :bundler2_config_use_hook, true # this is how to opt-in to bundler 2-style config. it's false by default
