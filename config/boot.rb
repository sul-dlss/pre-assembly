require 'rubygems'
require 'logger'

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

# Environment.
ENV_FILE = project_root + "/config/environments/#{environment}.rb"
require ENV_FILE

# Project dir in load path.
$LOAD_PATH.unshift(project_root + '/lib')

# Set up project logger.
require 'pre-assembly/logging'
PreAssembly::Logging.setup project_root, environment

# Load the project.
require 'pre-assembly'
