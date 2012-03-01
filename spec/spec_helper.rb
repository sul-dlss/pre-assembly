# TODO: environment currently set to development, but should be test?
environment = ENV['ROBOT_ENVIRONMENT'] ||= 'development'

bootfile = File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require bootfile
