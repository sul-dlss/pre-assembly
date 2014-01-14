require 'tmpdir'
require 'equivalent-xml'

puts "running in #{ENV['ROBOT_ENVIRONMENT']} mode"
bootfile = File.expand_path(File.dirname(__FILE__) + '/../config/boot')
require bootfile

tmp_output_dir = File.join(PRE_ASSEMBLY_ROOT, 'tmp')
FileUtils.mkdir_p tmp_output_dir


def noko_doc(x)
  Nokogiri.XML(x) { |conf| conf.default_xml.noblanks }
end