require 'tmpdir'
require 'fileutils'
require 'equivalent-xml'

environment = ENV['ROBOT_ENVIRONMENT'] ||= 'development'

bootfile = File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require bootfile
