require 'fileutils'
require 'erb'

# This file contains a serialized hash of LC subject heading terms for automobile and their LC URLs.  It is used by 
#  Revs when generating descriptive metadata.  See the "lib/pre_assembly/project/revs.rb" file
#  This cached set of terms can be re-generated with "ruby devel/revs_lc_automobile_terms.rb"
REVS_LC_TERMS_FILENAME=File.join(PRE_ASSEMBLY_ROOT,'lib','pre_assembly','project','revs-lc-marque-terms.obj')

# these are the names of special datastream files that will be staged in the 'metadata' folder instead of the 'content' folder
METADATA_FILES=['descMetadata.xml','contentMetadata.xml'].map(&:downcase)

# auto require any project specific files
Dir[File.dirname(__FILE__) + '/pre_assembly/project/*.rb'].each {|file| require "pre_assembly/project/#{File.basename(file)}" }

require 'pre_assembly/reporting'
require 'pre_assembly/druid_minter'
require 'pre_assembly/bundle'
require 'pre_assembly/digital_object'
require 'pre_assembly/object_file'
require 'pre_assembly/remediation/remediate'

require 'assembly-utils'
require 'assembly-image'
require 'rest_client'

# map the content type tags set inside an object to content metadata creation styles supported by the assembly-objectfile gem
# format is 'tag_value' => 'gem style name'
CONTENT_TYPE_TAG_MAPPING = {
  'Image'=>:simple_image,
  'File'=>:file,
  'Book (flipbook, ltr)'=>:simple_book,
  'Book (image-only)'=>:book_as_image,
  'Manuscript (flipbook, ltr)'=>:simple_book,
  'Manuscript (image-only)'=>:book_as_image,
  'Map'=>:map
}


