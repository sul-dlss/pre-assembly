require 'csv-mapper'

module Assembly

  class Bundle
    include Assembly::Logging
    include CsvMapper

    attr_accessor :manifest, :checksum_file

    def initialize()
      @manifest        = ''
      @checksum_file   = ''
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
      # Implement in subclass.
      log "check_for_required_files()"
    end

    def load_exp_checksums
      # Read checksums_file, using its content to populate @exp_checksums.
      # Implement in subclass.
      log "load_exp_checksums()"
    end

    def load_manifest
      # Read manifest and initialize digital objects.
      # Implement in subclass.
      log "load_manifest()"
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

    def check_for_required_files
      [@manifest, @checksum_file].each do |f|
        next if File.exists? f
        abort "Cannot proceed: could not find required file: #{f}\n"
      end
    end

    def load_manifest
      super
      csv_rows = import(@manifest) { read_attributes_from_file }
      csv_rows.each do |r|
        dobj = DigitalObject::new r.sourceid
        dobj.add_image r.filename
        @digital_objects.push dobj
      end
    end


    def load_exp_checksums
      super
      checksum_regex = %r{^MD5 \((.+)\) = (\w{32})$}
      IO.read(@checksum_file).scan(checksum_regex).each { |file_name, md5|
        @exp_checksums[file_name] = md5
      }
    end

  end

end
