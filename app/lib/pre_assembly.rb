require 'fileutils'
require 'erb'

# these are the names of special datastream files that will be staged in the 'metadata' folder instead of the 'content' folder
METADATA_FILES = ['descMetadata.xml', 'contentMetadata.xml'].map(&:downcase)

# auto require any project specific files
Dir[File.dirname(__FILE__) + '/pre_assembly/project/*.rb'].each { |file| require "pre_assembly/project/#{File.basename(file)}" }

require 'assembly-utils'
require 'assembly-image'
require 'rest_client'
require 'honeybadger'

# map the content type tags set inside an object to content metadata creation styles supported by the assembly-objectfile gem
# format is 'tag_value' => 'gem style name'
CONTENT_TYPE_TAG_MAPPING = {
  'Image' => :simple_image,
  'File' => :file,
  'Book (flipbook, ltr)' => :simple_book,
  'Book (image-only)' => :book_as_image,
  'Manuscript (flipbook, ltr)' => :simple_book,
  'Manuscript (image-only)' => :book_as_image,
  'Map' => :map
}
 