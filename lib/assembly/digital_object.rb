module Assembly

  class DigitalObject
    include Assembly::Logging

    attr_accessor :source_id, :already_processed, :druid, :images

    def initialize(source_id = '')
      @source_id         = source_id
      @already_processed = false
      @druid             = ''
      @images            = []
    end

    def add_image(file_name)
      @images.push Image::new(file_name)
    end

    def register
      # See SURI 2.0 confluence page for how to get a batch of druids in one call.
      # 
      #   curl -X POST 
      #        http://***REMOVED***@lyberservices-dev.stanford.edu:8080
      #        /suri2/namespaces/druid/identifiers?quantity=99
      log "    - register()"
    end

    def __register_object
      pid = Dor::SuriService.mint_id
      
      params = {
        :object_type  => 'item',
        :admin_policy => @apo_druid_id,
        :source_id    => @source_id,
        :pid          => "druid:#{druid.id}",
        :label        => "#{@project_name}_#{druid.id}",
        :tags         => ["Project : #{@project_name}"]
      }
      Dor::RegistrationService.register_object(params)
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
