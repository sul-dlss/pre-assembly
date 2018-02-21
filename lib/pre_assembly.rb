require 'fileutils'
require 'erb'

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
require 'pre_assembly/smpl_precontent_metadata'

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

module PreAssembly
  def self.retry_handler(method_name, logger, params = {})
    Proc.new do |exception, attempt_number, total_delay|
      logger.send "      ** #{method_name} FAILED **; with params of #{params.inspect}; and trying attempt #{attempt_number} of #{Dor::Config.dor.num_attempts}; delayed #{Dor::Config.dor.total_delay} seconds"
    end
  end

  UnknownError = Class.new(StandardError)
end
