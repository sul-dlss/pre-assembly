# frozen_string_literal: true

server 'sul-preassembly-prod.stanford.edu', user: 'preassembly', roles: %w[web app db worker]

set :rails_env, 'production'
