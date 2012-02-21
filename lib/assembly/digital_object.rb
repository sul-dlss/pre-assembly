module Assembly

  class DigitalObject

    include Assembly::Logging

    attr_accessor :source_id, :already_processed, :druid, :images

    def initialize(source_id = '')
      @already_processed = false
      @druid             = nil
      @images            = []

      # TODO: modify these hard-coded, REVS-specific values.
      @project_name      = 'revs'
      @apo_druid_id      = 'druid:qv648vd4392'
      @collection        = 'druid:nt028fd5773'
      @source_id         = {  @project_name => source_id }
      @source_id_key     = "#{@project_name}:#{source_id}"
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
