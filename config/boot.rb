require 'rubygems'
require 'bundler/setup'
require 'logger'

environment  = ENV['ROBOT_ENVIRONMENT'] ||= 'development'
PRE_ASSEMBLY_ROOT = File.expand_path(File.dirname(__FILE__) + '/..')
CERT_DIR = File.join(File.dirname(__FILE__), ".", "certs")

# Override Solrizer logger before it gets a chance to load and pollute STDERR.
require 'solrizer'
if Solrizer.respond_to? :logger
  solr_log        = Logger.new(PRE_ASSEMBLY_ROOT + "/log/solrizer_#{environment}.log")
  solr_log.level  = Logger::SEV_LABEL.index(ENV['ROBOT_LOG_LEVEL']) || Logger::INFO
  Solrizer.logger = solr_log
end

# General DLSS infrastructure.
require 'dor-services'

# Environment.
unless defined?(NO_ENVIRONMENT)
  ENV_FILE = PRE_ASSEMBLY_ROOT + "/config/environments/#{environment}.rb"
  require ENV_FILE
  Dor::WorkflowService.configure(Dor::Config.workflow.url,:dor_services_url => Dor::Config.dor.service_root.gsub('/v1',''))
end

# Project dir in load path.
$LOAD_PATH.unshift(PRE_ASSEMBLY_ROOT + '/lib')

# Set up project logger.
require 'pre_assembly/logging'
PreAssembly::Logging.setup PRE_ASSEMBLY_ROOT, environment

# Development dependencies.
if ['local', 'development'].include? environment
  require 'awesome_print'
end

# Load the project and its dependencies.
require 'pre_assembly'
