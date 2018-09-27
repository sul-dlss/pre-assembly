server 'sul-lyberservices-test.stanford.edu', user: 'lyberadmin', roles: %w[web app db]
set :repo_url, 'https://github.com/sul-dlss/pre-assembly.git'

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, 'test'
set :deploy_to, '/home/lyberadmin/pre-assembly'
set :branch, 'v3-legacy'

set :honeybadger_env, 'lyberservices-test'
