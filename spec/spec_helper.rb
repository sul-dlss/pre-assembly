require 'tmpdir'
require 'equivalent-xml'

environment = ENV['ROBOT_ENVIRONMENT'] ||= 'development'

bootfile = File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require bootfile

tmp_output_dir = File.join(PRE_ASSEMBLY_ROOT, 'tmp')
FileUtils.mkdir_p tmp_output_dir
