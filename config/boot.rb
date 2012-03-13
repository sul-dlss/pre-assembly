require 'rubygems'
require 'logger'

environment  = ENV['ROBOT_ENVIRONMENT'] ||= 'development'
PRE_ASSEMBLY_ROOT = File.expand_path(File.dirname(__FILE__) + '/..')

# Override Solrizer logger before it gets a chance to load and pollute STDERR.
require 'solrizer'
solr_log        = Logger.new(PRE_ASSEMBLY_ROOT + "/log/solrizer_#{environment}.log")
solr_log.level  = Logger::SEV_LABEL.index(ENV['ROBOT_LOG_LEVEL']) || Logger::INFO
Solrizer.logger = solr_log

# General DLSS infrastructure.
require 'dor-services'
require 'lyber_core'

# Environment.
ENV_FILE = PRE_ASSEMBLY_ROOT + "/config/environments/#{environment}.rb"
require ENV_FILE

# Project dir in load path.
$LOAD_PATH.unshift(PRE_ASSEMBLY_ROOT + '/lib')

# Set up project logger.
require 'pre_assembly/logging'
PreAssembly::Logging.setup PRE_ASSEMBLY_ROOT, environment

# Load the project and its dependencies.
require 'pre_assembly'
require 'pre_assembly/bundle'
require 'pre_assembly/digital_object'
require 'pre_assembly/image'
require 'pre_assembly/version'

require 'fileutils'
