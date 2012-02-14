module Assembly

  class DigitalObject
    include Assembly::Logging

    attr_accessor :source_id, :already_processed, :druid

    def initialize(source_id)
      @source_id         = source_id
      @already_processed = false
      @druid             = ''
      @images            = ['foo.tif', 'bar.tif'].map { |file_name| Image::new(file_name) }
    end

    def register
      # See SURI 2.0 confluence page for how to get a batch of druids in one call.
      # 
      #   curl -X POST 
      #        http://labware:lyberteam@lyberservices-dev.stanford.edu:8080
      #        /suri2/namespaces/druid/identifiers?quantity=99
      log "    - register()"
    end

    def modify_workflow
      log "    - modify_workflow()"
    end

    def process_images
      log "    - process_images()"
      @images.each do |img|
        img.process_image
      end
    end

    def generate_content_metadata
      log "    - generate_content_metadata()"
    end

    def generate_descriptive_metadata
      log "    - generate_descriptive_metadata()"
    end

    def persist
      log "    - persist()"
    end

  end # class DigitalObject

end # module Assembly
