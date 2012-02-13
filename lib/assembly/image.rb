module Assembly

  class Image
    include Assembly::Logger

    attr_accessor :file_name

    def initialize(file_name)
      @file_name = file_name
    end

    def process_image
      log "      - process_image(#{@file_name})"
      move_to_dor_workspace
      compute_exif_info
      compute_checksums
      compare_against_exp_checksums
      create_jp2
      persist
    end

    def move_to_dor_workspace
      log "        - move_to_dor_workspace()"
    end

    def compute_exif_info
      log "        - compute_exif_info()"
    end

    def compute_checksums
      log "        - compute_checksums()"
    end

    def compare_against_exp_checksums
      log "        - compare_against_exp_checksumsn()"
    end

    def create_jp2
      log "        - create_jp2()"
    end

    def persist
      log "        - persist()"
    end

  end # class Image

end


