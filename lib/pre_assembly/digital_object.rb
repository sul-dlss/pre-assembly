module PreAssembly

  class DigitalObject

    include PreAssembly::Logging
    include PreAssembly::ProjectSpecific
    
    INIT_PARAMS = [
      :container,
      :unadjusted_container,
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
      :dor_object,
      :reg_by_pre_assembly,
      :label,
      :manifest_row,
      :reaccession,
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
      @dor_object          = nil
      @reg_by_pre_assembly = false
      @label               = nil
      @source_id           = nil
      @manifest_row        = nil

      @content_md_file     = Assembly::CONTENT_MD_FILE
      @desc_md_file        = Assembly::DESC_MD_FILE
      @content_md_xml      = ''
      @desc_md_xml         = ''

      @pre_assem_finished = false
      @content_structure  = @project_style[:content_structure]
      @stager             = lambda { |f,d| FileUtils.cp_r f, d }
    end

    # compute the base druid tree folder for this object 
    def druid_tree_dir
      @druid_tree_dir ||= DruidTools::Druid.new(@druid.id,@staging_dir).path()      
    end
    
    def druid_tree_dir=(value)
      @druid_tree_dir=value
    end
    
    # the content subfolder
    def content_dir
      @content_dir ||= File.join(self.druid_tree_dir,'content')
    end
    
    # the metadata subfolder
    def metadata_dir
      @metadata_dir ||= File.join(self.druid_tree_dir,'metadata')      
    end
    
    ####
    # The main process.
    ####

    def pre_assemble
      log "  - pre_assemble(#{@source_id}) started"
      determine_druid
      
      prepare_for_reaccession if @reaccession
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
      @pid   = method("get_pid_from_#{k}").call
      @druid = DruidTools::Druid.new @pid
    end

    def get_pid_from_manifest
      @manifest_row[:druid]
    end
    
    def get_pid_from_suri
      Dor::SuriService.mint_id
    end
    
    def get_pid_from_druid_minter
      DruidMinter.next
    end
    
    def get_pid_from_container
      "druid:#{container_basename}"
    end

    def get_pid_from_container_barcode
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
      return unless @set_druid_id && @project_style[:should_register]
      log "    - add_dor_object_to_set(#{@set_druid_id})"
      @dor_object.add_relationship *add_member_relationship_params
      @dor_object.add_relationship *add_collection_relationship_params
      @dor_object.save
    end

    def add_member_relationship_params
      [:is_member_of, "info:fedora/#{@set_druid_id}"]
    end

    def add_collection_relationship_params
      [:is_member_of_collection, "info:fedora/#{@set_druid_id}"]
    end

    def prepare_for_reaccession
      # Used during a re-accession, will remove symlinks in /dor/workspace, files from the stacks and content in /dor/assembly
      # but will not unregister the object
      log "  - prepare_for_reaccession(#{@druid})"

      Assembly::Utils.cleanup_object(@druid.druid,[:stacks,:stage,:symlinks])
      
    end
    
    def unregister
      # Used during testing and development work to unregister objects created in -dev.
      # Do not run unless the object was registered by pre-assembly.
      return unless @reg_by_pre_assembly

      log "  - unregister(#{@pid})"

      Assembly::Utils.unregister(@pid)
      
      @dor_object          = nil
      @reg_by_pre_assembly = false
    end

    ####
    # Staging files.
    ####

    def stage_files
      # Create the druid tree within the staging directory,
      # and then copy-recursive all stageable items to that area.
      log "    - staging(druid_tree_dir = #{self.druid_tree_dir.inspect})"
      create_object_directories
      @stageable_items.each do |si_path|
        log "      - staging(#{si_path}, #{self.content_dir})", :debug
        # determine destination of staged file by looking to see if it is a known datastream XML file or not
        destination = METADATA_FILES.include?(File.basename(si_path).downcase) ? self.metadata_dir : self.content_dir
        @stager.call si_path, destination
      end
    end

    ####
    # Content metadata.
    ####

    def create_content_metadata
      # Invoke the contentMetadata creation method used by the
      # project, and then write that XML to a file.  
      # The name of the method invoked must be "create_content_metadata_xml_#{content_md_creation--style}", as defined in the YAML configuration
      # Custom methods are defined in the project_specific.rb file

      # if we are not using a standard known style of content metadata generation, pass the task off to a custom method
      if !['default','filename','dpg'].include? @content_md_creation[:style].to_s
        
        @content_md_xml = method("create_content_metadata_xml_#{@content_md_creation[:style]}").call
      
      else
        
        # otherwise use the content metadata generation gem
        params={:druid=>@druid.id,:objects=>content_object_files,:add_exif=>false,:bundle=>@content_md_creation[:style].to_sym,:style=>@project_style[:content_structure].to_sym}
        
        params.merge!(:add_file_attributes=>true,:file_attributes=>@publish_attr) unless @publish_attr.nil?
        
        @content_md_xml = Assembly::ContentMetadata.create_content_metadata(params)
        
      end

    end

    def generate_content_metadata
    
      create_content_metadata
      write_content_metadata
      
    end
    
    def write_content_metadata
      file_name = File.join self.metadata_dir, @content_md_file
      log "    - write_content_metadata_xml(#{file_name})"
      create_object_directories
      File.open(file_name, 'w') { |fh| fh.puts @content_md_xml }
    end

    def content_object_files
      # Object files that should be included in content metadata.
      @object_files.reject { |ofile| ofile.exclude_from_content }.sort
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

      # Note that the template uses the variable name `manifest_row`, so we set it here.
      manifest_row = @manifest_row
      
      # XML escape all of the entries in the manifest row so they won't break the XML
      manifest_row.each {|k,v| manifest_row[k]=Nokogiri::XML::Text.new(v,Nokogiri::XML('')).to_s if v }
      
      # Run the XML template through ERB. 
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
      file_name = File.join self.metadata_dir, @desc_md_file
      log "    - write_desc_metadata_xml(#{file_name})"
      create_object_directories
      File.open(file_name, 'w') { |fh| fh.puts @desc_md_xml }
    end

    def create_object_directories
      FileUtils.mkdir_p self.druid_tree_dir unless File.directory?(self.druid_tree_dir)
      FileUtils.mkdir_p self.metadata_dir unless File.directory?(self.metadata_dir)
      FileUtils.mkdir_p self.content_dir unless File.directory?(self.content_dir)
    end
    
    ####
    # Initialize the assembly workflow.
    ####

    def initialize_assembly_workflow
      
      # Call web service to add assemblyWF to the object in DOR.
      return unless @init_assembly_wf
      log "    - initialize_assembly_workflow()"
      url = assembly_workflow_url
      
      i=0
      success=false
      until i == Dor::Config.dor.num_attempts || success do
        i+=1
        begin
          result = RestClient.post url, {}
          success = true if result && [200,201,202,204].include?(result.code)
        rescue
          sleep Dor::Config.dor.sleep_time
        end
      end
      
      raise "initialize_assembly_workflow failed after #{i} attempts" if success == false
      
    end

    def assembly_workflow_url
      "#{Dor::Config.dor.service_root}/dor/v1/objects/#{@pid}/apo_workflows/assemblyWF"
    end

  end

end
