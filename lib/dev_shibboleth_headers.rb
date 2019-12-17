# frozen_string_literal: true

# This is a Rack middleware that we use in development. It sets an env var in such a way as to
# simulate the way mod_shib injects request headers that then result in an env var being set
# for the request.
#
# This is certainly not thread safe as it uses class level variables
class DevShibbolethHeaders
  class_attribute :user

  def initialize(app)
    @app = app
  end

  def call(env)
    # in development mode, devise will look for the user name to be provided by
    # ENV['REMOTE_USER'].  in other environments, it will check env['REMOTE_USER'].
    # we only want to set this default in dev anyway.
    ENV['REMOTE_USER'] ||= 'tmctesterson'
    @app.call(env)
  end
end
