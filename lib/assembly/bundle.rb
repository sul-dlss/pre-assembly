require 'csv-mapper'
require 'ftools'

module Assembly

  class Bundle
    include Assembly::Logging
    include CsvMapper

    attr_accessor(
      :bundle_dir,
      :manifest,
      :checksums_file,
      :project_name,
      :apo_druid_id,
      :collection_druid_id,
      :cleanup
    )

    def initialize(params = {})
      @bundle_dir          = params[:bundle_dir]
      @manifest            = params[:manifest]
      @checksums_file      = params[:checksums_file]
      @project_name        = params[:project_name]
      @apo_druid_id        = params[:apo_druid_id]
      @collection_druid_id = params[:collection_druid_id]
      @staging_dir         = params[:staging_dir]
      @copy_to_staging     = params[:copy_to_staging]
      @cleanup             = params[:cleanup]

      @exp_checksums       = {}
      @digital_objects     = []

      @file_handlers = {
        'copy' => lambda { |f, d| File.copy f, d },
        'move' => lambda { |f, d| File.move f, d },
      }
    end

    def run_assembly
      set_bundle_paths
      check_for_required_files
      load_exp_checksums
      load_manifest
      process_digital_objects
    end

    def set_bundle_paths
      @manifest       = full_path_in_bundle_dir @manifest
      @checksums_file = full_path_in_bundle_dir @checksums_file
    end

    def file_handler
      @file_handlers[@copy_to_staging ? 'copy' : 'move']
    end

    def full_path_in_bundle_dir(file)
      File.join @bundle_dir, file
    end

    def check_for_required_files
      log "check_for_required_files()"
      [@manifest, @checksums_file, @staging_dir].each do |f|
        next if File.exists? f
        abort "Cannot proceed: could not find required file or directory: #{f}\n"
      end
    end

    def load_exp_checksums
      # Read checksums_file, using its content to populate @exp_checksums.
      log "load_exp_checksums()"
      checksum_regex = %r{^MD5 \((.+)\) = (\w{32})$}
      IO.read(@checksums_file).scan(checksum_regex).each { |file_name, md5|
        @exp_checksums[file_name] = md5
      }
    end

    def load_manifest
      # Read manifest and initialize digital objects.
      log "load_manifest()"
      csv_rows = import(@manifest) { read_attributes_from_file }
      csv_rows.each do |r|
        # TODO: pass label if present.
        params = {
          :project_name        => @project_name,
          :apo_druid_id        => @apo_druid_id,
          :collection_druid_id => @collection_druid_id,
          :source_id           => r.sourceid,
        }

        dobj = DigitalObject::new params
        dobj.add_image r.filename
        @digital_objects.push dobj
      end
    end

    def process_digital_objects
      log "process_digital_objects()"
      fhandler = file_handler

      @digital_objects.each do |dobj|
        log "  - process_digital_object(#{dobj.source_id})"

        # Register.
        dobj.register

        # Copy or move images to staging directory.
        # TODO: should be a method on DigitalObject.
        dobj.images.each do |img|
          src = full_path_in_bundle_dir img.file_name
          log "    - copy-move(#{src}, #{@staging_dir})"
          fhandler.call src, @staging_dir
        end

        # Generate a skeleton content_metadata.xml file.
        # Store expected checksums and other provider-provided metadata in that file.
        # TODO.

        # Add common assembly workflow to the object, and put the object in the first state.
        # TODO.

        # During development, perform cleanup steps:
        #   - delete objects we registered
        next unless @cleanup
        dobj.delete_from_dor
      end
    end

  end

end
