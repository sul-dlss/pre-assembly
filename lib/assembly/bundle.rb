require 'csv-mapper'

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
      @checksums_file      = params[:check_sums_file]
      @project_name        = params[:project_name]
      @apo_druid_id        = params[:apo_druid_id]
      @collection_druid_id = params[:collection_druid_id]
      @cleanup             = params[:cleanup]

      @manifest       = File.join params[:bundle_dir], params[:manifest]
      @checksums_file = File.join params[:bundle_dir], params[:checksums_file]

      @exp_checksums   = {}
      @digital_objects = []
    end

    def run_assembly
      check_for_required_files
      load_exp_checksums
      load_manifest
      process_digital_objects
    end

    def check_for_required_files
      log "check_for_required_files()"
      [@manifest, @checksums_file].each do |f|
        next if File.exists? f
        abort "Cannot proceed: could not find required file: #{f}\n"
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
        # TODO: modify these hard-coded, REVS-specific values.
        params = {
          :project_name        => 'revs',
          :apo_druid_id        => 'druid:qv648vd4392',
          :collection_druid_id => 'druid:nt028fd5773',
          :source_id           => r.sourceid,
        }

        dobj = DigitalObject::new params
        dobj.add_image r.filename
        @digital_objects.push dobj
      end
    end

    def process_digital_objects
      log "process_digital_objects()"
      @digital_objects.each do |dobj|
        log "  - process_digital_object(#{dobj.source_id})"
        dobj.register

        # Move object to thumper staging directory (eg, dpgthumper-staging/PROJECT/DRUID_TREE).
        # Initialize the object's workflow in DOR.
        # Generate a skeleton content_metadata.xml file.

        dobj.nuke if @cleanup
      end
    end

  end

end
