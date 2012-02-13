# The gem is used by Stanford University Libraries
# to prepare and assemble collections to be
# accessioned.  It defines common tools used
# by Stanford to prepare digital materials.
#
# Author::    SULAIR DLSS
# see README for prerequisites

require 'assembly/version'
require 'assembly/bundle'
require 'assembly/images'
require 'assembly/image'
require 'assembly/image_info'
require 'assembly/digital_object'

module Assembly
  PATH_TO_GEM = File.expand_path(File.dirname(__FILE__) + '/..')
end
