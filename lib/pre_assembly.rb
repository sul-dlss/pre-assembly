Dor::Config.configure do

  pre_assembly do

    # Default file names.
    cm_file_name        'contentMetadata.xml'
    dm_file_name        'descMetadata.xml'
    manifest_file_name  'manifest.csv'
    checksums_file_name 'checksums.txt'
    descriptive_metadata_template 'mods_template.xml'

    # Default preserve-shelve-publish attribritutes for tifs.
    # Can be overridden in project-specific YAML file.
    preserve  'yes'
    shelve    'no'
    publish   'no'

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
require 'pre_assembly/object_file'
require 'pre_assembly/version'

require 'fileutils'
require 'assembly-image'
require 'checksum-tools'
