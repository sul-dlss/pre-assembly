require 'rubygems'
require 'logger'
# require 'yaml'

environment  = ENV['ROBOT_ENVIRONMENT'] ||= 'development'
project_root = File.expand_path(File.dirname(__FILE__) + '/..')

# Override Solrizer logger before it gets a chance to load and pollute STDERR.
require 'solrizer'
solr_log        = Logger.new(project_root + "/log/solrizer_#{environment}.log")
solr_log.level  = Logger::SEV_LABEL.index(ENV['ROBOT_LOG_LEVEL']) || Logger::INFO
Solrizer.logger = solr_log

# General DLSS infrastructure.
require 'dor-services'
require 'lyber_core'

# Load config for current environment.
$LOAD_PATH.unshift(project_root + '/lib')
ENV_FILE = project_root + "/config/environments/#{environment}.rb"
require ENV_FILE

# Set up project logger and load the project.
require 'assembly/logging'
Assembly::Logging.setup project_root, environment
require 'assembly'
