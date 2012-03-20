module PreAssembly

  class DigitalObject

    include PreAssembly::Logging

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
      :workflow_metadata_xml,
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


    ####
    # Initialization.
    ####

    def initialize(params = {})
      @project_name          = params[:project_name]
      @apo_druid_id          = params[:apo_druid_id]
      @collection_druid_id   = params[:collection_druid_id]
      @label                 = params[:label]
      @source_id             = { params[:project_name] => params[:source_id] }
      @druid                 = nil
      @pid                   = ''
      @images                = []
      @content_metadata_xml  = ''
      @content_md_file_name  = Dor::Config.pre_assembly.cm_file_name
      @desc_metadata_xml     = ''
      @desc_md_file_name     = Dor::Config.pre_assembly.dm_file_name
      @workflow_metadata_xml = ''
      @publish_attr          = Dor::Config.pre_assembly.publish_attr
      @registration_info     = nil
      @druid_tree_dir        = ''
    end

    def add_image(params)
      @images.push Image::new(params)
    end


    ####
    # The main process.
    ####

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


    ####
    # External dependencies.
    ####

    def get_druid_from_suri()
      Dor::SuriService.mint_id
    end

    def register_in_dor(params)      
      Dor::RegistrationService.register_object params
    end

    def delete_from_dor(pid)
      Dor::Config.fedora.client["objects/#{pid}"].delete
    end

    def create_workflow_in_dor(args)
      Dor::WorkflowService.create_workflow(*args)
    end

    def druid_tree_mkdir(dir)
      FileUtils.mkdir_p dir
    end

    def set_workflow_step_to_error(pid, step)
      wf_name = Dor::Config.pre_assembly.assembly_wf
      msg     = 'Integration testing'
      params  =  ['dor', pid, wf_name, step, msg]
      resp    = Dor::WorkflowService.update_workflow_error_status *params
      raise "update_workflow_error_status() returned false." unless resp == true
    end


    ####
    # Registration.
    ####

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

    def unregister
      # Used during testing/development work to unregister objects created in -dev.
      log "  - unregister(#{@pid})"

      # Set all assemblyWF steps to error.
      steps = Dor::Config.pre_assembly.assembly_wf_steps
      steps.each { |step, status| set_workflow_step_to_error @pid, step }

      # Delete object from Dor.
      delete_from_dor @pid
      @registration_info = nil
    end


    ####
    # Staging images.
    ####

    def stage_images(stager, base_target_dir)
      # Copy images to staging directory.
      @images.each do |img|
        @druid_tree_dir = @druid.path base_target_dir
        log "    - staging(#{img.full_path}, #{@druid_tree_dir})"
        druid_tree_mkdir @druid_tree_dir
        stager.call img.full_path, @druid_tree_dir
      end
    end


    ####
    # Content metadata.
    ####

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

    ####
    # Descriptive metadata.
    ####

    # this is customized per project
    def generate_desc_metadata
      log "    - generate_desc_metadata()"
      builder = Nokogiri::XML::Builder.new { |xml|
        xml.mods(MODS_XML_ATTR) {
          @images.each_with_index { |img, i|
            seq = i + 1
            xml.identifier(:file_name => img.file_name) {
              xml.typeOfResource "still image"
              xml.genre "digital image", :authority=>"att"
              xml.subject(:authority=>"att") {
                xml.topic "Automobile"
                xml.topic "History"
              }
              xml.location {xml.physicalLocation "Department of Special Collections, Stanford University Libraries", :type=>"repository"}
              xml.relatedItem(:type=>"host") {
                xml.titleInfo {
                  xml.title "The Collier Collection of the Revs Institute for Automotive Research"
                }
               xml.typeOfResource :collection=>"yes"
              }
              img.provider_attr.each { |k,v| 
                case k.to_s 
                  when 'label'
                    xml.titleInfo {xml.title v}
                  when 'year'
                    xml.originInfo {xml.dateCreated v}
                  when 'format'
                    xml.relatedItem(:type=>"original") {xml.physicalDescription {xml.form v,:authority=>"att"}}
                  when 'sourceid'
                    xml.identifier v, :type=>"local", :displayLabel=>"Revs ID"
                  when 'description'
                    xml.note v
                  else
                    xml.note(v, :type => "source note", :ID => k) unless v.empty?
                end
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


    ####
    # Workflow metadata.
    ####

    def generate_workflow_metadata
      log "    - generate_workflow_metadata()"
      wf_name = Dor::Config.pre_assembly.assembly_wf
      steps   = Dor::Config.pre_assembly.assembly_wf_steps
      builder = Nokogiri::XML::Builder.new { |xml|
        xml.workflow(:objectId => @druid.druid, :id => wf_name) {
          steps.each { |step, status|
            xml.process(:name => step, :status => status)
          }
        }
      }
      @workflow_metadata_xml = builder.to_xml
    end

    def initialize_assembly_workflow
      # Add assemblyWF to the object in DOR.
      wf_name = Dor::Config.pre_assembly.assembly_wf
      generate_workflow_metadata
      create_workflow_in_dor ['dor', @pid, wf_name, @workflow_metadata_xml]
    end

  end

end
