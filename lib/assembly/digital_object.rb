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
      # TODO: initialize: spec.
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
      @content_md_file_name  = 'content_metadata.xml'

      # TODO: initialize: set external dependencies at the bundle level?
      @uuid                  = UUIDTools::UUID.timestamp_create.to_s
      @druid_minting_service = lambda { Dor::SuriService.mint_id }
      @registration_service  = lambda { |ps| Dor::RegistrationService.register_object ps }
      @deletion_service      = lambda { |p| Dor::Config.fedora.client["objects/#{p}"].delete }
      @druid_tree_maker      = lambda { |d| FileUtils.mkdir_p d }
    end

    def add_image(file_name)
      # TODO: add_image: spec.
      @images.push Image::new(file_name)
    end

    def claim_druid
      # TODO: claim_druid: spec.
      @pid   = @druid_minting_service.call
      @druid = Druid.new @pid
    end

    def registration_params
      # TODO: registration_params: spec.
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
      # TODO: register: spec.
      claim_druid
      log "    - register(#{@pid})"
      @registration_service.call registration_params
    end

    def stage_images(stager, base_target_dir)
      # TODO: stage_images: spec.
      @images.each do |img|
        @druid_tree_dir = @druid.path base_target_dir
        log "    - staging(#{img.full_path}, #{@druid_tree_dir})"
        @druid_tree_maker.call @druid_tree_dir
        stager.call img.full_path, @druid_tree_dir
      end
    end

    def delete_from_dor
      # TODO: delete_from_dor: spec.
      log "    - delete_from_dor(#{@pid})"
      @deletion_service.call @pid
    end

    def generate_content_metadata
      # TODO: generate_content_metadata: spec.
      # TODO: generate_content_metadata: change this to produce YAML.
      # TODO: generate_content_metadata: pass publish-shelve-preseve via the bundle.
      publish  = 'no'
      preserve = 'yes'
      shelve   = 'no'

      log "    - generate_content_metadata()"

      builder = Nokogiri::XML::Builder.new { |xml|
        xml.contentMetadata(:objectId => "#{@druid.id}") {
          @images.each_with_index do |img, j|
            seq           = j + 1
            resource_id   = "#{@druid.id}_#{seq}"
            content_label = "Image #{seq}"

            xml.resource(:id => resource_id, :sequence => seq) {
              xml.label content_label
              xf_params = {
                :id       => img.file_name,
                :publish  => publish,
                :preserve => preserve,
                :shelve   => shelve,
              }
              xml.file(xf_params)
            }
          end
        }
      }

      @content_metadata_xml = builder.to_xml
    end

    def write_content_metadata(file_handle=nil)
      # TODO: write_content_metadata: spec.
      log "    - write_content_metadata()"
      unless file_handle
        file_name   = File.join @druid_tree_dir, @content_md_file_name
        file_handle = File.open(file_name, 'w')
      end
      file_handle.puts @content_metadata_xml
    end

  end

end
