module Assembly

  class DigitalObject

    include Assembly::Logging

    attr_accessor :source_id, :already_processed, :druid, :images

    def initialize(params = {})
      required_params = [ :project_name, :apo_druid_id, :collection_druid_id, :source_id ]
      raise ArgumentError unless required_params.all? { |k| params.has_key? k }

      @project_name        = params[:project_name]
      @apo_druid_id        = params[:apo_druid_id]
      @collection_druid_id = params[:collection_druid_id]
      @source_id           = { params[:project_name] => params[:source_id] }
      @druid               = nil
      @images              = []
    end

    def add_image(file_name)
      @images.push Image::new(file_name)
    end

    def register
      pid    = Dor::SuriService.mint_id
      @druid = Druid.new pid

      log "    - register(#{@druid.id})"
      
      params = {
        :object_type  => 'item',
        :admin_policy => @apo_druid_id,
        :source_id    => @source_id,
        :pid          => pid,
        :label        => "#{@project_name}_#{@druid.id}",
        :tags         => ["Project : #{@project_name}"],
        :other_ids    => { 'uuid' => UUIDTools::UUID.timestamp_create.to_s },
      }

      Dor::RegistrationService.register_object(params)
    end

    def nuke
      d = "druid:#{@druid.id}"
      log "    - nuke(#{d})"
      Dor::Config.fedora.client["objects/#{d}"].delete
    end

  end

end
