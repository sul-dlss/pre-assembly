module PreAssembly

  class DigitalObject

    include PreAssembly::Logging
    include PreAssembly::ProjectSpecific
    
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
      :desc_md_template_xml,
      :init_assembly_wf,
      :content_md_creation,
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
      :content_md_file,
      :desc_md_file,
      :content_md_xml,
      :desc_md_xml,
      :pre_assem_finished,
      :content_structure,
      :stager,
    ]

    (INIT_PARAMS + OTHER_ACCESSORS).each { |p| attr_accessor p }


    ####
    # Initialization.
    ####

    def initialize(params = {})
      INIT_PARAMS.each { |p| instance_variable_set "@#{p.to_s}", params[p] }
      setup
    end

    def setup
      @pid                 = ''
      @druid               = nil
      @druid_tree_dir      = ''
      @dor_object          = nil
      @reg_by_pre_assembly = false
      @label               = nil
      @source_id           = nil
      @manifest_row        = nil

      @content_md_file     = Dor::Config.pre_assembly.content_md_file
      @desc_md_file        = Dor::Config.pre_assembly.desc_md_file
      @content_md_xml      = ''
      @desc_md_xml         = ''

      @pre_assem_finished = false
      @content_structure  = @project_style[:content_structure]
      @stager             = lambda { |f,d| FileUtils.cp_r f, d }
      @get_pid_dispatch   = {
        :suri              => method(:get_pid_from_suri),
        :container         => method(:get_pid_from_container),
        :container_barcode => method(:get_pid_from_container_barcode),
      }
      @content_md_dispatch = {
        :default => method(:create_content_metadata_xml),
        :smpl    => method(:create_content_metadata_xml_smpl),
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
      log "    - pre_assemble(#{@pid}) finished"
    end


    ####
    # Determining the druid.
    ####

    def determine_druid
      k = @project_style[:get_druid_from]
      log "    - determine_druid(#{k})"
      @pid   = @get_pid_dispatch[k].call
      @druid = Druid.new @pid
    end

    def get_pid_from_suri()
      Dor::SuriService.mint_id
    end

    def get_pid_from_container
      return "druid:#{container_basename}"
    end

    def get_pid_from_container_barcode
      return DruidMinter.next if @project_style[:use_druid_minter]
      barcode = container_basename
      pids    = query_dor_by_barcode(barcode)
      pids.each do |pid|
        apo_pids = get_dor_item_apos(pid).map { |apo| apo.pid }
        return pid if apo_matches_exactly_one?(apo_pids)
      end
      return nil
    end

    def query_dor_by_barcode(barcode)
      return Dor::SearchService.query_by_id :barcode => barcode
    end

    def get_dor_item_apos(pid)
      begin
        item = Dor::Item.find pid
        return item.admin_policy_object
      rescue ActiveFedora::ObjectNotFoundError
        return []
      end
    end

    def apo_matches_exactly_one?(apo_pids)
      n = 0
      apo_pids.each { |pid| n += 1 if pid == @apo_druid_id }
      return n == 1
    end

    def container_basename
      return File.basename(@container)
    end


    ####
    # Registration and other Dor interactions.
    ####

    def register
      return unless @project_style[:should_register]
      log "    - register(#{@pid})"
      @dor_object          = register_in_dor(registration_params)
      @reg_by_pre_assembly = true
    end

    def register_in_dor(params)
      Dor::RegistrationService.register_object params
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

    def add_dor_object_to_set
      # Add the object to a set (a sub-collection).
      return unless @set_druid_id
      log "    - add_dor_object_to_set(#{@set_druid_id})"
      @dor_object.add_relationship *add_relationship_params
      @dor_object.save
    end

    def add_relationship_params
      [:is_member_of, "info:fedora/druid:#{@set_druid_id}"]
    end

    def unregister
      # Used during testing and development work to unregister objects created in -dev.
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

    def set_workflow_step_to_error(pid, step)
      wf_name = Dor::Config.pre_assembly.assembly_wf
      msg     = 'Integration testing'
      params  =  ['dor', pid, wf_name, step, msg]
      resp    = Dor::WorkflowService.update_workflow_error_status *params
      raise "update_workflow_error_status() returned false." unless resp == true
    end

    def delete_from_dor(pid)
      Dor::Config.fedora.client["objects/#{pid}"].delete
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

    def druid_tree_mkdir(dir)
      FileUtils.mkdir_p dir
    end


    ####
    # Content metadata.
    ####

    def generate_content_metadata
      # Invoke the contentMetadata creation method used by the
      # project (usually the default), and then write that XML to a file.
      @content_md_dispatch[@content_md_creation[:style]].call
      write_content_metadata
    end

    def create_content_metadata_xml
      # Default content metadata creation is here.
      # See lib/project_specific.rb for custom code by project.
      log "    - create_content_metadata_xml()"
      builder = Nokogiri::XML::Builder.new { |xml|
        xml.contentMetadata(node_attr_cm) {
          content_object_files.each_with_index { |object_file, i|
            seq = i + 1
            xml.resource(node_attr_cm_resource seq) {
              xml.label "Item #{seq}"
              xml.file(node_attr_cm_file object_file) {
                node_provider_checksum(xml, object_file.checksum)
              }
            }
          }
        }
      }
      @content_md_xml = builder.to_xml
    end

    def write_content_metadata
      file_name = File.join @druid_tree_dir, @content_md_file
      log "    - write_content_metadata_xml(#{file_name})"
      File.open(file_name, 'w') { |fh| fh.puts @content_md_xml }
    end

    def content_object_files
      # Object files that should be included in content metadata.
      @object_files.reject { |ofile| ofile.exclude_from_content }.sort
    end

    def node_attr_cm
      # Returns hash of attributes for a <contenteMetadata> node.
      h = { :objectId => @druid.id }
      h.merge!(:type => 'book') if @content_structure == :simple_book
      return h
    end

    def node_attr_cm_resource(seq)
      # Returns hash of attributes for a contenteMetadata <resource> node.
      h = { :sequence => seq, :id => "#{@druid.id}_#{seq}" }
      h.merge!(:type => 'page') if @content_structure == :simple_book
      return h
    end

    def node_attr_cm_file(object_file)
      # Returns hash of attributes for a contenteMetadata <file> node.
      return { :id => object_file.relative_path }.merge @publish_attr
    end

    def node_provider_checksum(xml, checksum)
      # Receives Nokogiri builder and a checksum.
      # Adds provider checksum node, but only if there is a checksum.
      xml.provider_checksum(checksum, :type => 'md5') if checksum
    end


    ####
    # Descriptive metadata.
    ####

    def generate_desc_metadata
      # Do nothing for bundles that don't suppy a template.
      return unless @desc_md_template_xml
      create_desc_metadata_xml
      write_desc_metadata
    end

    def create_desc_metadata_xml
      log "    - create_desc_metadata_xml()"

      # Run the XML through ERB. Note that the template uses the
      # variable name `manifest_row`, so we set it here.
      manifest_row = @manifest_row
      template     = ERB.new(@desc_md_template_xml, nil, '>')
      @desc_md_xml = template.result(binding)

      # The @manifest_row is a hash, with column names as the key.
      # In the template, users can specific placeholders inside
      # double brackets: "blah [[column_name]] blah".
      # Here we replace those placeholders with the corresponding value
      # from the manifest row.
      @manifest_row.each { |k,v| @desc_md_xml.gsub! "[[#{k}]]", v.to_s }
      return true
    end

    def write_desc_metadata
      file_name = File.join @druid_tree_dir, @desc_md_file
      log "    - write_desc_metadata_xml(#{file_name})"
      File.open(file_name, 'w') { |fh| fh.puts @desc_md_xml }
    end


    ####
    # Initialize the assembly workflow.
    ####

    def initialize_assembly_workflow
      # Call web service to add assemblyWF to the object in DOR.
      return unless @init_assembly_wf
      log "    - initialize_assembly_workflow()"
      url = assembly_workflow_url
      RestClient.post url, {}
    end

    def assembly_workflow_url
      "#{Dor::Config.dor.service_root}/dor/v1/objects/#{@pid}/apo_workflows/assemblyWF"
    end

  end

end
