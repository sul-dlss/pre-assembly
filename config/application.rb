require_relative 'boot'
require 'rails/all'
require_relative 'erubis_monkeypatch.rb'

CERT_DIR = File.join(File.dirname(__FILE__), ".", "certs")

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module PreAssembly
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end

# Old Environment.
require_relative "cli_environments/#{Rails.env}.rb"
