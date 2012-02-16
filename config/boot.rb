require 'rubygems'
require 'logger'

# Using test as default environment, because the development
# environment is not being fully maintained at the moment.
environment   = ENV['ROBOT_ENVIRONMENT'] ||= 'development'
assembly_root = File.expand_path(File.dirname(__FILE__) + '/..')
log_level     = Logger::SEV_LABEL.index(ENV['ROBOT_LOG_LEVEL']) || Logger::INFO

# Override Solrizer logger before it gets a chance to load and pollute STDERR.
require 'solrizer'
assembly_log       = Logger.new(assembly_root + "/log/#{environment}.log")
assembly_log.level = log_level
Solrizer.logger    = assembly_log

# General DLSS infrastructure.
require 'dor-services'
require 'lyber_core'

# Load our environment and gem.
$LOAD_PATH.unshift(assembly_root + '/lib')
ENV_FILE = assembly_root + "/config/environments/#{environment}.rb"
require ENV_FILE
require 'assembly'
