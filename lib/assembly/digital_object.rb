module Assembly

  class DigitalObject

    include Assembly::Logging

    attr_accessor(
      :project_name,
      :apo_druid_id,
      :collection_druid_id,
      :label,
      :source_id,
      :druid,
      :pid,
      :images,
      :content_metadata_xml,
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
      @label                 = params[:label]
      @source_id             = { params[:project_name] => params[:source_id] }
      @druid                 = nil
      @pid                   = ''
      @images                = []
      @content_metadata_xml  = ''

      # TODO: initialize: set external dependencies at the bundle level?
      @uuid                  = UUIDTools::UUID.timestamp_create.to_s
      @druid_minting_service = lambda { Dor::SuriService.mint_id }
      @registration_service  = lambda { |ps| Dor::RegistrationService.register_object ps }
      @deletion_service      = lambda { |p| Dor::Config.fedora.client["objects/#{p}"].delete }
      @druid_tree_maker      = lambda { |d| FileUtils.mkdir_p d }
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
        :label        => "#{@project_name}_#{@label || @druid.id}",
        :tags         => ["Project : #{@project_name}"],
        :other_ids    => { 'uuid' => @uuid },
      }
    end

    def register
      claim_druid
      log "    - register(#{@pid})"
      @registration_service.call registration_params
    end

    def stage_images(stager, base_target_dir)
      @images.each do |img|
        @target_dir = @druid.path base_target_dir
        log "    - staging(#{img.full_path}, #{@target_dir})"
        @druid_tree_maker.call @target_dir
        stager.call img.full_path, @target_dir
      end
    end

    def delete_from_dor
      log "    - delete_from_dor(#{@pid})"
      @deletion_service.call @pid
    end

    def generate_content_metadata
      log "    - generate_content_metadata()"

      # TODO: generate_content_metadata: XML needs mods namespace?
      # TODO: generate_content_metadata: how should these parameters be passed in?
      content_type_description = "image"
      attr_params              = ["uncropped", {:name => 'representation'}]
      publish                  = 'no'
      preserve                 = 'yes'
      shelve                   = 'no'
      content_label            = 'REVS'

      builder = Nokogiri::XML::Builder.new { |xml|
        xml.contentMetadata(:objectId => "#{@druid.id}",:type => content_type_description) {
          @images.each_with_index do |img, j|
            seq = j + 1
            resource_id = "#{@druid.id}_#{seq}"
            xml.resource(:id => resource_id, :sequence => seq, :type => content_type_description) {
              xml.label content_label
              xf_params = {
                :id       => img.file_name,
                :publish  => publish,
                :preserve => preserve,
                :shelve   => shelve,
              }
              xml.file(xf_params) {
                xml.attr *attr_params
              }
            }
          end
        }
      }

      @content_metadata_xml = builder.to_xml
    end

    def write_content_metadata
      # TODO write_content_metadata: implement it.
      log "    - write_content_metadata()"
      puts @content_metadata_xml
    end

  end

end
