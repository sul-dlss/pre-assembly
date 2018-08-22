server 'sul-lyberservices-prod.stanford.edu', user: 'lyberadmin', roles: %w{web app db}

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, "production"
set :deploy_to, '/home/lyberadmin/pre-assembly'
