module Assembly

  class DigitalObject

    include Assembly::Logging

    attr_accessor :source_id, :already_processed, :druid, :images

    def initialize(source_id = '')
      @source_id         = source_id
      @already_processed = false
      @druid             = ''
      @images            = []
      @project_name      = 'REVS'              # TODO
      @apo_druid_id      = 'druid:qv648vd4392' # TODO
      @collection        = 'druid:nt028fd5773' # TODO
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

      pid   = Dor::SuriService.mint_id
      druid = Druid.new pid
      params = {
        :object_type  => 'item',
        :admin_policy => @apo_druid_id,
        :source_id    => @source_id,
        :label        => "#{@project_name}_#{druid.id}",
        :tags         => ["Project : #{@project_name}"]
      }

      p params
      exit

      result = Dor::RegistrationService.register_object(params)
      p result
      exit
      # Returns:
      # result = {
      #   :response => http_response,
      #    :pid => pid
      # }
      
    end

  end

end
