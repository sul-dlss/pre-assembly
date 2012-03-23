Dor::Config.configure do

  pre_assembly do

    # Default file names.
    cm_file_name        'contentMetadata.xml'
    dm_file_name        'descMetadata.xml'
    manifest_file_name  'manifest.cvs'
    checksums_file_name 'checksums.txt'

    # Default preserve-shelve-publish attribritutes.
    publish_attr Hash[:preserve => 'yes', :shelve => 'yes', :publish => 'yes']

    # The assembly workflow parameters.
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

require 'pre_assembly/bundle'
require 'pre_assembly/digital_object'
require 'pre_assembly/image'
require 'pre_assembly/version'

require 'fileutils'

