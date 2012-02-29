# TODO: sort out environment issues; current set to development.
environment = ENV['ROBOT_ENVIRONMENT'] ||= 'development'

bootfile = File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require bootfile
