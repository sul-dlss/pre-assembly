module Assembly

  # TODO: use the Ruby logger.
  module Logger
    def log(msg, level = :info)
      puts msg
    end
  end


  class Bundle
    include Assembly::Logger

    def initialize(manifest, exp_checksums)
      @manifest      = manifest
      @exp_checksums = exp_checksums
    end

    def run_assembly
      sanity_check
      load_manifest
      load_exp_checksums
      process_digital_objects
    end

    def sanity_check
      log "sanity_check()"
    end

    def load_manifest
      log "load_manifest()"
      @digital_objects = (0..2).map { |source_id| DigitalObject::new(source_id) }
      @digital_objects[0].already_processed = true
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

  end # class Bundle

end # module Assembly
