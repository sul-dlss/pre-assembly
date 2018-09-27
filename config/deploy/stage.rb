server 'sul-preassembly-stage.stanford.edu', user: 'preassembly', roles: %w[web app db]

Capistrano::OneTimeKey.generate_one_time_key!
set :rails_env, 'production'
