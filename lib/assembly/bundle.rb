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
      :staging_dir,
      :copy_to_staging,
      :cleanup,
      :exp_checksums,
      :digital_objects,
      :stagers,
      :required_files
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

      @stagers = {
        :copy => lambda { |f,d| File.copy f, d },
        :move => lambda { |f,d| File.move f, d },
      }
      set_bundle_paths
    end

    def set_bundle_paths
      @manifest       = full_path_in_bundle_dir @manifest
      @checksums_file = full_path_in_bundle_dir @checksums_file
      @required_files = [@manifest, @checksums_file, @staging_dir]
    end

    def run_assembly
      check_for_required_files
      load_exp_checksums
      load_manifest
      process_digital_objects
      delete_digital_objects if @cleanup
    end

    def full_path_in_bundle_dir(file)
      File.join @bundle_dir, file
    end

    def get_stager
      # TODO: get_stager: return a closure containing @staging_dir.
      @stagers[@copy_to_staging ? :copy : :move]
    end

    def check_for_required_files
      log "check_for_required_files()"
      @required_files.each do |f|
        next if file_exists f
        raise IOError, "Required file or directory not found: #{f}\n"
      end
    end

    def file_exists(file)
      File.exists? file
    end

    def load_exp_checksums
      # Read checksums_file, using its content to populate a hash of expected checksums.
      log "load_exp_checksums()"
      checksum_regex = %r{^MD5 \((.+)\) = (\w{32})$}
      read_exp_checksums.scan(checksum_regex).each { |file_name, md5|
        @exp_checksums[file_name] = md5
      }
    end

    def read_exp_checksums
      IO.read @checksums_file
    end

    def load_manifest
      # Read manifest and initialize digital objects.
      log "load_manifest()"
      parse_manifest.each do |r|
        dobj_params = {
          :project_name        => @project_name,
          :apo_druid_id        => @apo_druid_id,
          :collection_druid_id => @collection_druid_id,
          :source_id           => r.sourceid,
          :label               => r.label,
        }

        dobj = DigitalObject::new dobj_params
        dobj.add_image(
          :file_name => r.filename,
          :full_path => full_path_in_bundle_dir(r.filename)
        )
        @digital_objects.push dobj
      end
    end

    def parse_manifest
      return import(@manifest) { read_attributes_from_file }
    end

    def process_digital_objects
      log "process_digital_objects()"
      stager = get_stager
      @digital_objects.each { |dobj| dobj.assemble(stager, @staging_dir) }
    end

    def delete_digital_objects
      # During development, delete objects the we register.
      log "delete_digital_objects()"
      @digital_objects.each { |dobj| dobj.delete_from_dor }
    end

  end

end
