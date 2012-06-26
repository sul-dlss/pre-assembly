Dor::Config.configure do

  assembly do

    # Default file names when writing metadata streams.
    content_md_file 'contentMetadata.xml'
    desc_md_file    'descMetadata.xml'

    # Defaut workspace and assembly areas, used in cleanup
    dor_workspace      '/dor/workspace'
    assembly_workspace '/dor/assembly'  # can be overwritten by the value set in the project specific YAML configuration
    
    # The assembly workflow parameters
    # TODO Remove these when they are no longer needed to unregister an object
    assembly_wf  'assemblyWF'
    assembly_wf_steps [
      [ 'start-assembly',        'completed' ],
      [ 'jp2-create',            'waiting'   ],
      [ 'checksum-compute',      'waiting'   ],
      [ 'exif-collect',          'waiting'   ],
      [ 'accessioning-initiate', 'waiting'   ],
    ]
  end

end

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
require 'checksum-tools'
require 'rest_client'
