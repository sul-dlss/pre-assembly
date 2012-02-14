require 'csv-mapper'

module Assembly

  class Bundle
    include Assembly::Logging
    include CsvMapper

    def initialize(manifest, exp_checksums)
      @manifest        = manifest
      @exp_checksums   = exp_checksums
      @digital_objects = []
    end

    def run_assembly
      check_for_required_files
      load_manifest
      load_exp_checksums
      process_digital_objects
    end

    def check_for_required_files
      # TODO: manifest file should exist.
      #       exp_checksums files should exits.
      log "check_for_required_files()"
    end

    def load_manifest
      # Read manifest and initialize digital objects.
      log "load_manifest()"
    end

    def load_exp_checksums
      log "load_exp_checksums()"
    end

    def process_digital_objects
      log "process_digital_objects()"
      @digital_objects.each do |dobj|
        msg = "  - process_digital_object(#{dobj.source_id})"
        if dobj.already_processed
          log msg + ' [SKIPPING: already processed]'
        else
          log msg
          dobj.register
          dobj.modify_workflow
          dobj.process_images
          dobj.generate_content_metadata
          dobj.generate_descriptive_metadata
          dobj.persist
        end
      end
    end

  end

  class RevsBundle < Bundle

    def load_manifest
      super

      manifest_rows = import(@manifest) { read_attributes_from_file }
      manifest_rows.each do |mrow|
        dobj = DigitalObject::new(mrow.sourceid)
        dobj.add_image mrow.filename
        @digital_objects.push dobj
      end
    end

  end

end
