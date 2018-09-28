server 'sul-lyberservices-prod.stanford.edu', user: 'lyberadmin', roles: %w[web app db]
set :repo_url, 'https://github.com/sul-dlss/pre-assembly.git'

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, 'production'
set :branch, 'v3-legacy'

set :honeybadger_env, 'lyberservices-prod'
