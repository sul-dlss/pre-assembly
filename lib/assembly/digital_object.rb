module Assembly

  class DigitalObject

    include Assembly::Logging

    attr_accessor(
      :project_name,
      :apo_druid_id,
      :collection_druid_id,
      :source_id,
      :druid,
      :pid,
      :images,
      :uuid,
      :druid_minting_service,
      :registration_service,
      :deletion_service
    )

    def initialize(params = {})
      required = [ :project_name, :apo_druid_id, :collection_druid_id, :source_id ]
      raise ArgumentError unless required.all? { |k| params.has_key? k }

      @project_name          = params[:project_name]
      @apo_druid_id          = params[:apo_druid_id]
      @collection_druid_id   = params[:collection_druid_id]
      @source_id             = { params[:project_name] => params[:source_id] }
      @druid                 = nil
      @pid                   = ''
      @images                = []
      @uuid                  = UUIDTools::UUID.timestamp_create.to_s
      @druid_minting_service = lambda { Dor::SuriService.mint_id }
      @registration_service  = lambda { |ps| Dor::RegistrationService.register_object ps }
      @deletion_service      = lambda { |p| Dor::Config.fedora.client["objects/#{p}"].delete }
    end

    def add_image(file_name)
      @images.push Image::new(file_name)
    end

    def claim_druid
      @pid   = @druid_minting_service.call
      @druid = Druid.new @pid
    end

    def registration_params
      {
        :object_type  => 'item',
        :admin_policy => @apo_druid_id,
        :source_id    => @source_id,
        :pid          => @pid,
        :label        => "#{@project_name}_#{@druid.id}",
        :tags         => ["Project : #{@project_name}"],
        :other_ids    => { 'uuid' => @uuid },
      }
    end

    def register
      claim_druid
      log "    - register(#{@pid})"
      @registration_service.call registration_params
    end

    def delete_from_dor
      log "    - nuke(#{@pid})"
      @deletion_service.call @pid
    end

  end

end
