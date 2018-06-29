server 'sul-preassembly-prod.stanford.edu', user: 'preassembly', roles: %w{web app db}

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, "production"

set :rvm_ruby_version, '2.4.4'
set :deploy_to, '/opt/app/preassembly/pre-assembly'
set :linked_files, []
set :repo_url, 'ssh://git@github.com/sul-dlss/pre-assembly'
