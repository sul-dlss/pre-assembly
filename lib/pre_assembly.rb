require 'fileutils'
require 'erb'

require 'pre_assembly/reporting'
require 'pre_assembly/druid_minter'
require 'pre_assembly/bundle'
require 'pre_assembly/project_specific'
require 'pre_assembly/digital_object'
require 'pre_assembly/object_file'

require 'assembly-utils'
require 'assembly-image'
require 'rest_client'

# map the content type tags set inside an object to content metadata creation styles supported by the assembly-objectfile gem
# format is 'tag_value' => 'gem style name'
CONTENT_TYPE_TAG_MAPPING = {
  'Image'=>:simple_image,
  'File'=>:file,
  'Book (flipbook, ltr)'=>:book_with_pdf,
  'Book (image-only)'=>:book_as_image,
  'Manuscript (flipbook, ltr)'=>:book_with_pdf,
  'Manuscript (image-only)'=>:book_as_image,
  'Map'=>:map
}