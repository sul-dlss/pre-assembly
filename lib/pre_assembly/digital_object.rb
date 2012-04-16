require 'rest_client'

module PreAssembly

  class DigitalObject

    include PreAssembly::Logging

    INIT_PARAMS = [
      :container,
      :stageable_items,
      :object_files,
      :project_style,
      :project_name,
      :apo_druid_id,
      :set_druid_id,
      :publish_attr,
      :bundle_dir,
      :staging_dir,
      :desc_meta_template,
      :init_assembly_wf,
    ]

    OTHER_ACCESSORS = [
      :pid,
      :druid,
      :druid_tree_dir,
      :dor_object,
      :reg_by_pre_assembly,
      :label,
      :manifest_row,
      :source_id,
      :content_md_file_name,
      :desc_md_file_name,
      :content_metadata_xml,
      :desc_metadata_xml,
      :stager,
      :get_pid_dispatch,
    ]

    (INIT_PARAMS + OTHER_ACCESSORS).each { |p| attr_accessor p }


    ####
    # Initialization.
    ####

    def initialize(params = {})
      INIT_PARAMS.each { |p| instance_variable_set "@#{p.to_s}", params[p] }

      @pid                  = ''
      @druid                = nil
      @druid_tree_dir       = ''
      @dor_object           = nil
      @reg_by_pre_assembly  = false
      @label                = nil
      @source_id            = nil
      @manifest_row         = nil

      @content_md_file_name = Dor::Config.pre_assembly.cm_file_name
      @desc_md_file_name    = Dor::Config.pre_assembly.dm_file_name
      @content_metadata_xml = ''
      @desc_metadata_xml    = ''

      @stager           = lambda { |f,d| FileUtils.cp_r f, d }
      @get_pid_dispatch = {
        :style_revs   => method(:get_pid_from_suri),
        :style_rumsey => method(:get_pid_from_container),
      }
    end


    ####
    # The main process.
    ####

    def pre_assemble
      log "  - pre_assemble(#{@source_id}) started"
      determine_druid
      register
      add_dor_object_to_set
      stage_files
      generate_content_metadata
      generate_desc_metadata
      initialize_assembly_workflow
      log "  - pre_assemble(#{@pid}) finished"
    end


    ####
    # External dependencies.
    ####

    def get_pid_from_suri()
      Dor::SuriService.mint_id
    end

    def register_in_dor(params)
      Dor::RegistrationService.register_object params
    end

    def add_dor_object_to_set
      return unless @set_druid_id
      @dor_object.add_relationship *add_relationship_params
      @dor_object.save
    end

    def delete_from_dor(pid)
      Dor::Config.fedora.client["objects/#{pid}"].delete
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
    # Project-specific dispatching.
    ####

    def should_register
      return @project_style == :style_revs
    end


    ####
    # Registration.
    ####

    def determine_druid
      @pid   = @get_pid_dispatch[@project_style].call
      @druid = Druid.new @pid
    end

    def get_pid_from_container
      return "druid:#{File.basename @container}"
    end

    def register
      return unless should_register
      log "    - register(#{@pid})"
      @dor_object          = register_in_dor(registration_params)
      @reg_by_pre_assembly = true
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
      # Do not run unless the object was registered by pre-assembly.
      return unless @reg_by_pre_assembly

      log "  - unregister(#{@pid})"

      # Set all assemblyWF steps to error.
      steps = Dor::Config.pre_assembly.assembly_wf_steps
      steps.each { |step, status| set_workflow_step_to_error @pid, step }

      # Delete object from Dor.
      delete_from_dor @pid
      @dor_object          = nil
      @reg_by_pre_assembly = false
    end


    ####
    # Staging files.
    ####

    def stage_files
      # Create the druid tree within the staging directory,
      # and then copy-recursive all stageable items to that area.
      @druid_tree_dir = @druid.path(@staging_dir)
      druid_tree_mkdir @druid_tree_dir
      @stageable_items.each do |si_path|
        log "    - staging(#{si_path}, #{@druid_tree_dir})"
        @stager.call si_path, @druid_tree_dir
      end
    end


    ####
    # Content metadata.
    ####

    def generate_content_metadata
      create_content_metadata_xml
      write_content_metadata
    end

    def create_content_metadata_xml
      builder = Nokogiri::XML::Builder.new { |xml|
        xml.contentMetadata(:objectId => @druid.id) {
          content_object_files.each_with_index { |ofile, i|
            seq = i + 1
            xml.resource(:sequence => seq, :id => "#{@druid.id}_#{seq}") {
              file_params = { :id => ofile.relative_path }.merge @publish_attr
              xml.label "Item #{seq}"
              xml.file(file_params) {
                xml.provider_checksum ofile.checksum, :type => 'md5'
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

    def content_object_files
      # Object files that should be included in content metadata.
      @object_files.reject { |ofile| ofile.exclude_from_content }
    end


    ####
    # Descriptive metadata.
    ####

    def generate_desc_metadata
      # Do nothing for bundles that don't suppy a template.
      return unless @desc_meta_template
      create_desc_metadata_xml
      write_desc_metadata
    end

    def create_desc_metadata_xml
      log "    - create_desc_metadata_xml()"

      # Run the XML through ERB. Note that the template uses the
      # variable name `manifest_row`, so we set it here.
      manifest_row       = @manifest_row
      template           = ERB.new(@desc_meta_template)
      @desc_metadata_xml = template.result(binding)

      # The @manifest_row is a hash, with column names as the key.
      # In the template, users can specific placeholders inside
      # double brackets: "blah [[column_name]] blah".
      # Here we replace those placeholders with the corresponding value
      # from the manifest row.
      @manifest_row.each { |k,v| @desc_metadata_xml.gsub! "[[#{k}]]", v.to_s }
      return true
    end

    def write_desc_metadata
      file_name = File.join @druid_tree_dir, @desc_md_file_name
      log "    - write_desc_metadata_xml(#{file_name})"
      File.open(file_name, 'w') { |fh| fh.puts @desc_metadata_xml }
    end


    ####
    # Initialize the assembly workflow.
    ####

    def initialize_assembly_workflow
      # Call web service to add assemblyWF to the object in DOR.
      return unless @init_assembly_wf
      url = assembly_workflow_url
      RestClient.post url, {}
    end

    def assembly_workflow_url
      "#{Dor::Config.dor.service_root}/dor/v1/objects/#{@pid}/apo_workflows/assemblyWF"
    end

  end

end
