# frozen_string_literal: true

set :application, 'pre-assembly'
set :repo_url, 'ssh://git@github.com/sul-dlss/pre-assembly'

# set :ssh_options,
#     keys: [Capistrano::OneTimeKey.temporary_ssh_private_key_path],
#     forward_agent: true,
#     auth_methods: %w[publickey password]

# Default branch is :main
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
append :linked_files, 'config/honeybadger.yml', 'config/database.yml'

# Default value for linked_dirs is []
append :linked_dirs, 'log', 'config/certs', 'config/settings', 'tmp', 'vendor/bundle'

set :sidekiq_systemd_role, :worker
set :sidekiq_systemd_use_hooks, true

# Manage sneakers via systemd (from dlss-capistrano gem)
set :sneakers_systemd_use_hooks, true

set :whenever_identifier, -> { "#{fetch(:application)}_#{fetch(:stage)}" }

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

# update shared_configs before restarting app
before 'deploy:restart', 'shared_configs:update'

set :honeybadger_env, fetch(:stage)
