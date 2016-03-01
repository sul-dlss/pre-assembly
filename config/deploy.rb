# config valid only for Capistrano 3
lock '3.4.0'

set :rvm_ruby_version, '2.2.4'      # Defaults to: 'default'
set :application, 'pre-assembly'
set :repo_url, 'git@github.com:sul-dlss/pre-assembly.git'

set :ssh_options, {
  keys: [Capistrano::OneTimeKey.temporary_ssh_private_key_path],
  forward_agent: true,
  auth_methods: %w(publickey password)
}

# Default branch is :master
ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/home/lyberadmin/pre-assembly'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w{}

# Default value for linked_dirs is []
set :linked_dirs, %w{log config/certs config/environments tmp vendor/bundle}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5
