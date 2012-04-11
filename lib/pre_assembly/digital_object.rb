module PreAssembly

  class DigitalObject

    include PreAssembly::Logging

    attr_accessor(
      :container,
      :stageable_items,
      :object_files,
      :manifest_attr,
      :reg_by_pre_assembly,
      :project_name,
      :apo_druid_id,
      :set_druid_id,
      :label,
      :source_id,
      :druid,
      :pid,
      :images,
      :content_metadata_xml,
      :content_md_file_name,
      :desc_metadata_xml,
      :desc_metadata_xml_template,
      :desc_md_file_name,
      :workflow_metadata_xml,
      :dor_object,
      :druid_tree_dir,
      :publish_attr
    )


    ####
    # Initialization.
    ####

    def initialize(params = {})
      @container                  = params[:container]
      @stageable_items            = params[:stageable_items]
      @object_files               = params[:object_files]
      @manifest_attr              = params[:manifest_attr]
      @reg_by_pre_assembly        = false
      @project_name               = params[:project_name]
      @apo_druid_id               = params[:apo_druid_id]
      @set_druid_id               = params[:set_druid_id]
      @label                      = params[:label]
      @source_id                  = params[:source_id]
      @druid                      = nil
      @pid                        = ''
      @images                     = []
      @content_metadata_xml       = ''
      @content_md_file_name       = Dor::Config.pre_assembly.cm_file_name
      @desc_metadata_xml          = ''
      @desc_metadata_xml_template = params[:desc_metadata_xml_template]
      @desc_md_file_name          = Dor::Config.pre_assembly.dm_file_name
      @workflow_metadata_xml      = ''
      @dor_object                 = nil
      @druid_tree_dir             = ''
      @publish_attr               = {
        :preserve => params[:preserve],
        :shelve   => params[:shelve],
        :publish  => params[:publish],
      }
    end

    def add_image(params)
      @images.push Image::new(params)
    end


    ####
    # The main process.
    ####

    def pre_assemble(stager, staging_dir)
      log "  - assemble(#{@source_id})"

      claim_druid
      register

      add_dor_object_to_set
      stage_images stager, staging_dir

      generate_content_metadata
      write_content_metadata

      generate_desc_metadata
      write_desc_metadata

      initialize_assembly_workflow
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

    def add_dor_object_to_set
      @dor_object.add_relationship *add_relationship_params
      @dor_object.save
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
      @dor_object = register_in_dor(registration_params)
    end

    def registration_params
      {
        :object_type  => 'item',
        :admin_policy => @apo_druid_id,
        :source_id    => { @project_name => @source_id },
        :pid          => @pid,
        :label        => @label,
        :tags         => ["Project : #{@project_name}"],
      }
    end

    def add_relationship_params
      [:is_member_of, "info:fedora/druid:#{@set_druid_id}"]
    end

    def unregister
      # Used during testing/development work to unregister objects created in -dev.
      log "  - unregister(#{@pid})"

      # Set all assemblyWF steps to error.
      steps = Dor::Config.pre_assembly.assembly_wf_steps
      steps.each { |step, status| set_workflow_step_to_error @pid, step }

      # Delete object from Dor.
      delete_from_dor @pid
      @dor_object = nil
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

    def generate_desc_metadata
      log "    - generate_desc_metadata()"

      # this is a helper variable that gives you the first row in the manifest for the digital image, so you can use it to create metadata in the template
      manifest_row=@images.first.provider_attr
      
      # run the XML through ERB to do any parsing that the template requires
      # and then return the result into nokogiri
      template=ERB.new(@desc_metadata_xml_template)      
      @desc_metadata_xml=template.result(binding)
      
      # now iterate over all the columns in the manifest
      # and replace any placeholder tags for the manifest column in the metadata template
      manifest_row.each {|k,v| @desc_metadata_xml.gsub!("[[#{k.to_s}]]",v.to_s) }
      
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
