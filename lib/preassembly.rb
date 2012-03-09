# Author:: SULAIR DLSS.
# See README for prerequisites.

require 'csv-mapper'
require 'fileutils'

require 'preassembly/version'

require 'preassembly/bundle'
require 'preassembly/digital_object'
require 'preassembly/image'

module PreAssembly
  PATH_TO_GEM = File.expand_path(File.dirname(__FILE__) + '/..')
end
