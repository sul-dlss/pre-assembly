# frozen_string_literal: true

server 'sul-preassembly-stage.stanford.edu', user: 'preassembly', roles: %w[web app db worker]

set :rails_env, 'production'
