ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

require 'rubygems'
require 'bundler/setup'

environment = ENV['RAILS_ENV'] || 'development'
PRE_ASSEMBLY_ROOT = File.expand_path(File.dirname(__FILE__) + '/..')
CERT_DIR = File.join(File.dirname(__FILE__), ".", "certs")

# Environment.
# ENV_FILE = PRE_ASSEMBLY_ROOT + "/config/cli_environments/#{environment}.rb"
require_relative "cli_environments/#{environment}.rb"
