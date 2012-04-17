Dor::Config.configure do

  pre_assembly do

    # Default file names when writing metadata streams.
    content_md_file 'contentMetadata.xml'
    desc_md_file    'descMetadata.xml'

    # The assembly workflow parameters
    # TODO Remove these when they are no longer needed to unregister an object
    assembly_wf  'assemblyWF'
    assembly_wf_steps [
      [ 'start-assembly',        'completed' ],
      [ 'jp2-create',            'waiting'   ],
      [ 'checksum-compute',      'waiting'   ],
      [ 'checksum-compare',      'waiting'   ],
      [ 'exif-collect',          'waiting'   ],
      [ 'accessioning-initiate', 'waiting'   ],
    ]
  end

end

require 'fileutils'
require 'erb'

require 'pre_assembly/druid_minter'
require 'pre_assembly/bundle'
require 'pre_assembly/digital_object'
require 'pre_assembly/object_file'
require 'pre_assembly/version'

require 'assembly-image'
require 'checksum-tools'
