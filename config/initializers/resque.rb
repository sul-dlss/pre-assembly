# frozen_string_literal: true

require 'resque/failure/redis_multi_queue'

# load environment specific configuration
config_file = Rails.root.join('config', 'resque.yml')
resque_config = YAML.safe_load(ERB.new(File.read(config_file)).result)
Resque.redis = resque_config[Rails.env.to_s]

# configure a separate failure queue per job queue
Resque::Failure.backend = Resque::Failure::RedisMultiQueue

# see https://github.com/resque/resque/issues/1591#issuecomment-403805957
# this silences a burdensome deprecation warning, while we wait for the gem to update
Redis::Namespace.class_eval do
  def client
    _client
  end
end
