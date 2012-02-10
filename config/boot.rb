require 'rubygems'

ASSEMBLY_ROOT = File.expand_path(File.dirname(__FILE__) + '/..')

$LOAD_PATH.unshift File.expand_path(ASSEMBLY_ROOT + '/lib')

# Recursively require all .rb files in the lib directory.
Dir["#{ASSEMBLY_ROOT}/lib/**/*.rb"].sort.each { |f| require f }
