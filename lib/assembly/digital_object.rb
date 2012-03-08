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
      :content_md_file_name,
      :public_attr,
      :desc_metadata_xml,
      :desc_md_file_name,
      :registration_info,
      :druid_tree_dir
    )

    MODS_XML_ATTR = {
      'xmlns'              => "http://www.loc.gov/mods/v3",
      'version'            => "3.3",
      'xmlns:xsi'          => "http://www.w3.org/2001/XMLSchema-instance",
      'xsi:schemaLocation' => "http://www.loc.gov/mods/v3 " +
                              "http://www.loc.gov/standards/mods/v3/mods-3-3.xsd",
    }

    def initialize(params = {})
      @project_name         = params[:project_name]
      @apo_druid_id         = params[:apo_druid_id]
      @collection_druid_id  = params[:collection_druid_id]
      @label                = params[:label]
      @source_id            = { params[:project_name] => params[:source_id] }
      @druid                = nil
      @pid                  = ''
      @images               = []
      @content_metadata_xml = ''
      @content_md_file_name = 'content_metadata.xml'
      @desc_metadata_xml    = ''
      @desc_md_file_name    = 'desc_metadata.xml'
      @publish_attr         = { :preserve => 'yes', :shelve => 'no', :publish => 'no' }
      @registration_info    = nil
      @druid_tree_dir       = ''
    end

    def get_druid_from_suri()   Dor::SuriService.mint_id                           end
    def register_in_dor(params) Dor::RegistrationService.register_object params    end
    def delete_from_dor(pid)    Dor::Config.fedora.client["objects/#{pid}"].delete end
    def druid_tree_mkdir(dir)   FileUtils.mkdir_p dir                              end

    def add_image(params)
      @images.push Image::new(params)
    end

    def assemble(stager, staging_dir)
      log "  - assemble(#{@source_id})"
      claim_druid
      register
      stage_images stager, staging_dir
      generate_content_metadata
      generate_desc_metadata
      write_content_metadata
      initialize_assembly_workflow
      write_desc_metadata
    end

    def claim_druid
      log "    - claim_druid()"
      @pid   = get_druid_from_suri
      @druid = Druid.new @pid
    end

    def register
      log "    - register(#{@pid})"
      @registration_info = register_in_dor(registration_params)
    end

    def registration_params
      {
        :object_type  => 'item',
        :admin_policy => @apo_druid_id,
        :source_id    => @source_id,
        :pid          => @pid,
        :label        => @label,
        :tags         => ["Project : #{@project_name}"],
      }
    end

    def stage_images(stager, base_target_dir)
      # Copy or move images to staging directory.
      @images.each do |img|
        @druid_tree_dir = @druid.path base_target_dir
        log "    - staging(#{img.full_path}, #{@druid_tree_dir})"
        druid_tree_mkdir @druid_tree_dir
        stager.call img.full_path, @druid_tree_dir
      end
    end

    def generate_content_metadata
      builder = Nokogiri::XML::Builder.new { |xml|
        xml.contentMetadata(:objectId => @druid.id) {
          @images.each_with_index { |img, i|
            seq = i + 1
            xml.resource(:sequence => seq, :id => "#{@druid.id}_#{seq}") {
              file_params = { :id => img.file_name }.merge @publish_attr
              xml.label "Image #{seq}"
              xml.file(file_params) {
                xml.provider_checksum img.exp_md5, :type => 'md5'
              }
            }
          }
        }
      }
      @content_metadata_xml = builder.to_xml
    end

    def write_content_metadata
      file_name = File.join @druid_tree_dir, @content_md_file_name
      log "    - write_content_metadata_xml(#{file_name})"
      File.open(file_name, 'w') { |fh| fh.puts @content_metadata_xml }
    end

    def generate_desc_metadata
      log "    - generate_desc_metadata()"
      builder = Nokogiri::XML::Builder.new { |xml|
        xml.mods(MODS_XML_ATTR) {
          @images.each_with_index { |img, i|
            seq = i + 1
            xml.identifier(:file_name => img.file_name) {
              img.provider_attr.each { |k,v| 
                xml.note v, :type => "source note", :ID => k
              }
            }
          }
        }
      }
      @desc_metadata_xml = builder.to_xml
    end

    def write_desc_metadata
      file_name = File.join @druid_tree_dir, @desc_md_file_name
      log "    - write_desc_metadata_xml(#{file_name})"
      File.open(file_name, 'w') { |fh| fh.puts @desc_metadata_xml }
    end

    def generate_workflow_metadata
      log "    - generate_workflow_metadata()"
      builder = Nokogiri::XML::Builder.new { |xml|
        xml.workflow(:objectID => @pid, :id => "assemblyWF") {
          ['start-assembly', 'checksum', 'checksum-compare'].each { |wf|
            status = wf == 'start-assembly' ? 'completed' : 'waiting'
            xml.process(:status => status, :name => wf)
          }
        }
      }
      @workflow_metadata_xml = builder.to_xml


      # Dor::WorkflowService.create_workflow('dor', {druid}, 'assemblyWF', '<workfow....>')
    end

    def initialize_assembly_workflow
      # Add assemblyWF to the object in DOR.
    end

    def unregister
      # Used during testing/development work to unregister objects created in -dev.
      log "  - unregister(#{@pid})"
      delete_from_dor @pid
      @registration_info = nil
    end

  end

end
