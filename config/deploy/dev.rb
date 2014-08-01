server 'sul-lyberservices-dev.stanford.edu', user: 'lyberadmin', roles: %w{web app db}

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, "development"
set :bundle_without, ""
