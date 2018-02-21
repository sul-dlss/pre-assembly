# encoding: UTF-8
require 'modsulator'

module PreAssembly

  class DigitalObject

    include PreAssembly::Logging

    # include any project specific files
    Dir[File.dirname(__FILE__) + '/project/*.rb'].each {|file| include "PreAssembly::Project::#{File.basename(file).gsub('.rb','').camelize}".constantize }

    INIT_PARAMS = [
      :container,
      :unadjusted_container,
      :stageable_items,
      :object_files,
      :project_style,
      :project_name,
      :apply_tag,
      :apo_druid_id,
      :set_druid_id,
      :publish_attr,
      :bundle_dir,
      :staging_dir,
      :desc_md_template_xml,
      :init_assembly_wf,
      :content_md_creation,
      :new_druid_tree_format,
      :staging_style,
      :smpl_manifest
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
      :technical_md_file,
      :desc_md_file,
      :content_md_xml,
      :technical_md_xml,
      :desc_md_xml,
      :pre_assem_finished,
      :content_structure
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
      @label               = Dor::Config.dor.default_label
      @source_id           = nil
      @manifest_row        = nil

      @content_md_file     = Assembly::CONTENT_MD_FILE
      @technical_md_file   = Assembly::TECHNICAL_MD_FILE
      @desc_md_file        = Assembly::DESC_MD_FILE
      @content_md_xml      = ''
      @technical_md_xml    = ''
      @desc_md_xml         = ''


      @pre_assem_finished = false
      @content_structure  = (@project_style ? @project_style[:content_structure] : 'file')

    end

    def stager(source,destination)
      if @staging_style.nil? || @staging_style == 'copy'
        FileUtils.cp_r source, destination
      else
        FileUtils.ln_s source, destination, :force=>true
      end
    end

    def content_md_creation_style
      # set this object's content_md_creation_style
      if (@project_style[:should_register]) || (!@project_style[:content_tag_override]) || (@project_style[:content_tag_override] && content_type_tag.blank?) # if this object needs to be registered or has no content type tag for a registered object, use the default set in the YAML file
        default_content_md_creation_style
      else # if the object is already registered and there is a content type tag and we allow overrides, use it if we know what it means (else use the default)
        CONTENT_TYPE_TAG_MAPPING[content_type_tag] || default_content_md_creation_style
      end
    end

    def default_content_md_creation_style
       @project_style[:content_structure].to_sym
    end

    # compute the base druid tree folder for this object
    def druid_tree_dir
      @druid_tree_dir ||=  (@new_druid_tree_format ? DruidTools::Druid.new(@druid.id,@staging_dir).path() : Assembly::Utils.get_staging_path(@druid.id,@staging_dir))
    end

    def druid_tree_dir=(value)
      @druid_tree_dir=value
    end

    # the content subfolder
    def content_dir
      @content_dir ||= (@new_druid_tree_format ? File.join(druid_tree_dir,'content') : druid_tree_dir)
    end

    # the metadata subfolder
    def metadata_dir
      @metadata_dir ||=  (@new_druid_tree_format ? File.join(druid_tree_dir,'metadata') : druid_tree_dir)
    end

    ####
    # The main process.
    ####

    def pre_assemble(desc_md_xml=nil)

      @desc_md_template_xml = desc_md_xml

      log "  - pre_assemble(#{@source_id}) started"
      determine_druid

      prepare_for_reaccession if @reaccession
      register
      add_dor_object_to_set
      stage_files
      generate_content_metadata unless @content_md_creation[:style].to_s == 'none'
      generate_technical_metadata
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

      i=0
      success=false
      backtrace=""
      exception_message=""
      result=nil

      until i == Dor::Config.dor.num_attempts || success do
        i+=1
        begin
          result = Dor::SuriService.mint_id
          success = (result.class == String)
        rescue Exception => e
          log "      ** GET_PID_FROM_SURI FAILED **, and trying attempt #{i} of #{Dor::Config.dor.num_attempts} in #{Dor::Config.dor.sleep_time} seconds"
          backtrace=e.backtrace
          exception_message=e.message
          sleep Dor::Config.dor.sleep_time
        end
      end

      if success == false || result.nil?
        error_message = "get_pid_from_suri failed after #{i} attempts\n"
        log error_message
        error_message += "exception: #{exception_message}\n"
        error_message += "backtrace: #{backtrace}"
        raise error_message
      else
        return result
      end

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
        @pid=pid
        apo_pids = get_dor_item_apos.map { |apo| apo.pid }
        return pid if apo_matches_exactly_one?(apo_pids)
      end
      nil
    end

    def query_dor_by_barcode(barcode)
      Dor::SearchService.query_by_id :barcode => barcode
    end

    def get_dor_item_apos(pid)
      get_dor_object
      @dor_object.nil? ? [] : @dor_object.admin_policy_object
    end

    def get_dor_object
      begin
        @dor_object ||= Dor::Item.find pid
      rescue ActiveFedora::ObjectNotFoundError
        @dor_object = nil
      end
    end

    def content_type_tag
      get_dor_object
      @dor_object.nil? ? "" : @dor_object.content_type_tag
    end

    def apo_matches_exactly_one?(apo_pids)
      n = 0
      apo_pids.each { |pid| n += 1 if pid == @apo_druid_id }
      n == 1
    end

    def container_basename
      File.basename(@container)
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

      i=0
      success=false
      backtrace=""
      exception_message=""
      result=nil

      until i == Dor::Config.dor.num_attempts || success do
        i+=1
        begin
          result = Dor::RegistrationService.register_object params
          success = (result.class == Dor::Item)
        rescue Exception => e
          source_id="#{@project_name}:#{@source_id}"
          log "      ** REGISTER FAILED ** with '#{e.message}' ... deleting object #{@pid} and source id #{source_id} and trying attempt #{i} of #{Dor::Config.dor.num_attempts} in #{Dor::Config.dor.sleep_time} seconds"
          sourceid_pids=Dor::SearchService.query_by_id(source_id)
          all_pids=sourceid_pids << @pid
          all_pids.each do |pid|
            begin
              Dor::SearchService.solr.delete_by_id(pid)  # should be unnecessary, but handles an edge case where the object is not in Fedora, but is in Solr
              Dor::Config.fedora.client["objects/#{pid}"].delete
            rescue Exception => e1
              log "      ... could not delete object with #{pid} or source id #{source_id} : #{e1.message} ..."
            end
          end
          Dor::SearchService.solr.commit
          backtrace=e.backtrace
          exception_message=e.message
          sleep Dor::Config.dor.sleep_time
        end
      end

      if success == false || result.nil?
        error_message = "register_in_dor failed after #{i} attempts; with params of #{params} \n"
        log error_message
        error_message += "exception: #{exception_message}\n"
        error_message += "backtrace: #{backtrace}"
        raise error_message
      else
        return result
      end

    end

    def registration_params
      tags=["Project : #{@project_name}"]
      tags << @apply_tag unless @apply_tag.blank?
      {
        :object_type  => 'item',
        :admin_policy => @apo_druid_id,
        :source_id    => { @project_name => @source_id },
        :pid          => @pid,
        :label        => @label.blank? ? Dor::Config.dor.default_label : @label,
        :tags         => tags,
      }
    end

    def add_dor_object_to_set
      # Add the object to a set (a sub-collection).
      return unless @set_druid_id && @project_style[:should_register]
      log "    - add_dor_object_to_set(#{@set_druid_id})"

      i=0
      success=false
      exception=nil
      until i == Dor::Config.dor.num_attempts || success do
        i+=1
        begin
          Array(@set_druid_id).each do |druid|
            @dor_object.add_relationship *add_member_relationship_params(druid)
            @dor_object.add_relationship *add_collection_relationship_params(druid)
          end
          success = @dor_object.save
        rescue Exception => e
          log "      ** ADD_DOR_OBJECT_TO_SET FAILED **, and trying attempt #{i} of #{Dor::Config.dor.num_attempts} in #{Dor::Config.dor.sleep_time} seconds"
          exception = e
          sleep Dor::Config.dor.sleep_time
        end
      end

      if success == false
        error_message = "add_dor_object_to_set failed after #{i} attempts; for druid=#{pid} and set=#{@set_druid_id} \n"
        log error_message
        wrapped_exception = e.exception(error_message + e.message)
        wrapped_exception.set_backtrace(e.backtrace)
        raise wrapped_exception
      end

    end

    def add_member_relationship_params(druid)
      [:is_member_of, "info:fedora/#{druid}"]
    end

    def add_collection_relationship_params(druid)
      [:is_member_of_collection, "info:fedora/#{druid}"]
    end

    def prepare_for_reaccession
      # Used during a re-accession, will remove symlinks in /dor/workspace, files from the stacks and content in /dor/assembly, workflows
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
      log "    - staging(druid_tree_dir = #{druid_tree_dir.inspect})"
      create_object_directories
      @stageable_items.each do |si_path|
        log "      - staging(#{si_path}, #{content_dir})", :debug
        # determine destination of staged file by looking to see if it is a known datastream XML file or not
        destination = METADATA_FILES.include?(File.basename(si_path).downcase) ? metadata_dir : content_dir
        stager si_path, destination
      end
    end

    ####
    # Technical metadata combined file for SMPL.
    ####
    def generate_technical_metadata

      create_technical_metadata
      write_technical_metadata

    end

    def create_technical_metadata
      # create technical metadata for smpl projects only
      return unless @content_md_creation[:style].to_s == 'smpl'

      tm = Nokogiri::XML::Document.new
      tm_node = Nokogiri::XML::Node.new("technicalMetadata", tm)
      tm_node['objectId']=@pid
      tm_node['datetime']=Time.now.utc.strftime("%Y-%m-%d-T%H:%M:%SZ")
      tm << tm_node

      # find all technical metadata files and just append the xml to the combined technicalMetadata
      current_directory=Dir.pwd
      FileUtils.cd(File.join(@bundle_dir,container_basename))
      tech_md_filenames=Dir.glob("**/*_techmd.xml").sort
      tech_md_filenames.each do |filename|
         tech_md_xml = Nokogiri::XML(File.open(File.join(@bundle_dir,container_basename,filename)))
         tm.root << tech_md_xml.root
      end
      FileUtils.cd(current_directory)
      @technical_md_xml=tm.to_xml

    end

    def write_technical_metadata
      # write technical metadata out to a file only if it exists
      return if @technical_md_xml.blank?

      file_name = File.join metadata_dir, @technical_md_file
      log "    - write_technical_metadata_xml(#{file_name})"
      create_object_directories
      File.open(file_name, 'w') { |fh| fh.puts @technical_md_xml }
    end

    ####
    # Content metadata.
    ####
    def generate_content_metadata

      create_content_metadata
      write_content_metadata

    end

    def create_content_metadata
      # Invoke the contentMetadata creation method used by the project
      # The name of the method invoked must be "create_content_metadata_xml_#{content_md_creation--style}", as defined in the YAML configuration
      # Custom methods are defined in the project_specific.rb file

      # if we are not using a standard known style of content metadata generation, pass the task off to a custom method
      if !['default','filename','dpg','none'].include? @content_md_creation[:style].to_s

        @content_md_xml = method("create_content_metadata_xml_#{@content_md_creation[:style]}").call

      elsif @content_md_creation[:style].to_s != 'none' # and assuming we don't want any contentMetadata, then use the Assembly gem to generate CM

        # otherwise use the content metadata generation gem
        params={:druid=>@druid.id,:objects=>content_object_files,:add_exif=>false,:bundle=>@content_md_creation[:style].to_sym,:style=>content_md_creation_style}

        params.merge!(:add_file_attributes=>true,:file_attributes=>@publish_attr.stringify_keys) unless @publish_attr.nil?

        @content_md_xml = Assembly::ContentMetadata.create_content_metadata(params)

      end

    end

    def write_content_metadata
      # write content metadata out to a file
      return if @content_md_creation[:style].to_s == 'none'
      file_name = File.join metadata_dir, @content_md_file
      log "    - write_content_metadata_xml(#{file_name})"
      create_object_directories

      File.open(file_name, 'w') { |fh| fh.puts @content_md_xml }

      # NOTE: This is being skipped because it now removes empty nodes, and we need an a node like this: <file id="filename" /> when first starting with contentMetadat
      #        If this node gets removed, then nothing works.  - Peter Mangiafico, October 3, 2015
      # mods_xml_doc = Nokogiri::XML(@content_md_xml) # create a nokogiri doc
      # normalizer = Normalizer.new
      # normalizer.normalize_document(mods_xml_doc.root) # normalize it
      # File.open(file_name, 'w') { |fh| fh.puts mods_xml_doc.to_xml } # write out normalized result

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

      # Note that the template uses the variable name `manifest_row`, so we set it here
      manifest_row = @manifest_row

      # XML escape all of the entries in the manifest row so they won't break the XML
      manifest_row.each {|k,v| manifest_row[k]=Nokogiri::XML::Text.new(v,Nokogiri::XML('')).to_s if v }

      # ensure access with symbol or string keys
      manifest_row = manifest_row.with_indifferent_access

      # Run the XML template through ERB.
      template     = ERB.new(@desc_md_template_xml, nil, '>')
      @desc_md_xml = template.result(binding)

      # The @manifest_row is a hash, with column names as the key.
      # In the template, as a conviennce we allow users to put specific column placeholders inside
      # double brackets: "blah [[column_name]] blah".
      # Here we replace those placeholders with the corresponding value
      # from the manifest row.
      @manifest_row.each { |k,v| @desc_md_xml.gsub! "[[#{k}]]", v.to_s.strip }
      true

    end

    def write_desc_metadata
      file_name = File.join metadata_dir, @desc_md_file
      log "    - write_desc_metadata_xml(#{file_name})"
      create_object_directories
      File.open(file_name, 'w') { |fh| fh.puts @desc_md_xml }
    end

    def create_object_directories
      FileUtils.mkdir_p druid_tree_dir unless File.directory?(druid_tree_dir)
      FileUtils.mkdir_p metadata_dir unless File.directory?(metadata_dir)
      FileUtils.mkdir_p content_dir unless File.directory?(content_dir)
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
      backtrace=""
      exception_message=""
      until i == Dor::Config.dor.num_attempts || success do
        i+=1
        begin
          result = RestClient.post url, {}
          success = true if result && [200,201,202,204].include?(result.code)
        rescue Exception => e
          log "      ** INITIALIZE ASSEMBLY WORKFLOW FAILED **, and trying attempt #{i} of #{Dor::Config.dor.num_attempts} in #{Dor::Config.dor.sleep_time} seconds"
          backtrace=e.backtrace
          exception_message=e.message
          sleep Dor::Config.dor.sleep_time
        end
      end

      if success == false
        error_message = "initialize_assembly_workflow failed after #{i} attempts; with URL of #{url} \n"
        log error_message
        error_message += "exception: #{exception_message}\n"
        error_message += "backtrace: #{backtrace}"
        raise error_message
      end

    end

    def assembly_workflow_url
      druid = @pid.include?('druid') ? @pid : "druid:#{@pid}"
      "#{Dor::Config.dor.service_root}/objects/#{druid}/apo_workflows/assemblyWF"
    end

  end

end
