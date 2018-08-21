require 'rubygems'
require 'bundler/setup'
require 'logger'

environment = ENV['RAILS_ENV'] ||= 'development'
PRE_ASSEMBLY_ROOT = File.expand_path(File.dirname(__FILE__) + '/..')
CERT_DIR = File.join(File.dirname(__FILE__), ".", "certs")

# General DLSS infrastructure.
require 'dor-services'

# Environment.
# ENV_FILE = PRE_ASSEMBLY_ROOT + "/config/cli_environments/#{environment}.rb"
require_relative "cli_environments/#{environment}.rb"
Dor::Config.dor_services.url ||= Dor::Config.dor.service_root
Dor::Config.workflow.client.configure(Dor::Config.workflow.url, :dor_services_url => Dor::Config.dor_services.url.gsub('/v1', ''))


# Project dir in load path.
$LOAD_PATH.unshift(PRE_ASSEMBLY_ROOT + '/lib')

# Set up project logger.
require 'pre_assembly/logging'
PreAssembly::Logging.setup PRE_ASSEMBLY_ROOT, environment

# Load the project and its dependencies.
require 'pre_assembly'

require 'revs-utils'

class RevsUtils
  extend Revs::Utils
end
