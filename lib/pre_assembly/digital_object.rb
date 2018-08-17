# encoding: UTF-8

require 'modsulator'

module PreAssembly
  class DigitalObject
    include PreAssembly::Logging

    # include any project specific files
    Dir[File.dirname(__FILE__) + '/project/*.rb'].each { |file| include "PreAssembly::Project::#{File.basename(file).gsub('.rb', '').camelize}".constantize }

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
      :file_attr,
      :bundle_dir,
      :staging_dir,
      :desc_md_template_xml,
      :init_assembly_wf,
      :content_md_creation,
      :new_druid_tree_format,
      :staging_style,
      :smpl_manifest
    ]

    attr_accessor :pid,
                  :reg_by_pre_assembly,
                  :label,
                  :reaccession,
                  :content_md_file,
                  :technical_md_file,
                  :desc_md_file,
                  :content_md_xml,
                  :technical_md_xml,
                  :desc_md_xml,
                  :pre_assem_finished,
                  :content_structure

    attr_writer :dor_object, :druid_tree_dir
    attr_accessor :druid, :source_id, :manifest_row

    INIT_PARAMS.each { |p| attr_accessor p }

    ####
    # Initialization.
    ####

    def initialize(params = {})
      INIT_PARAMS.each { |p| instance_variable_set "@#{p}", params[p] }
      self.file_attr ||= params[:publish_attr]
      setup
    end

    def setup
      self.pid = ''
      self.label              = Dor::Config.dor.default_label
      self.content_md_file    = Assembly::CONTENT_MD_FILE
      self.technical_md_file  = Assembly::TECHNICAL_MD_FILE
      self.desc_md_file       = Assembly::DESC_MD_FILE
      self.content_md_xml     = ''
      self.technical_md_xml   = ''
      self.desc_md_xml        = ''
      self.content_structure  = (project_style ? project_style[:content_structure] : 'file')
    end

    def stager(source, destination)
      if staging_style.nil? || staging_style == 'copy'
        FileUtils.cp_r source, destination
      else
        FileUtils.ln_s source, destination, :force => true
      end
    end

    # set this object's content_md_creation_style
    def content_md_creation_style
      # if this object needs to be registered, we will set the content type specified in YAML config no matter what
      # if this object does NOT to be registered (:should_register == false) and the user has NOT asked for overrides (content_tag_override == false), we will also just set the content type specified in YAML config
      if @project_style[:should_register] || !@project_style[:content_tag_override]
        default_content_md_creation_style
      else # this means the object is pre-registered and the user has asked us to set the content type from the object if possible (if object type can't be determined, use the content type specified in YAML config)
        CONTENT_TYPE_TAG_MAPPING[content_type_tag] || default_content_md_creation_style
      end
    end

    def default_content_md_creation_style
      project_style[:content_structure].to_sym
    end

    # compute the base druid tree folder for this object
    def druid_tree_dir
      @druid_tree_dir ||= (new_druid_tree_format ? DruidTools::Druid.new(druid.id, staging_dir).path() : Assembly::Utils.get_staging_path(druid.id, staging_dir))
    end

    def content_dir
      @content_dir ||= (new_druid_tree_format ? File.join(druid_tree_dir, 'content') : druid_tree_dir)
    end

    # the metadata subfolder
    def metadata_dir
      @metadata_dir ||= (new_druid_tree_format ? File.join(druid_tree_dir, 'metadata') : druid_tree_dir)
    end

    ####
    # The main process.
    ####

    def pre_assemble(desc_md_xml = nil)
      self.desc_md_template_xml = desc_md_xml

      log "  - pre_assemble(#{source_id}) started"
      determine_druid

      prepare_for_reaccession if reaccession
      register
      add_dor_object_to_set
      stage_files
      generate_content_metadata unless content_md_creation[:style].to_s == 'none'
      generate_technical_metadata
      generate_desc_metadata
      initialize_assembly_workflow
      log "    - pre_assemble(#{pid}) finished"
    end

    ####
    # Determining the druid.
    ####

    def determine_druid
      k = project_style[:get_druid_from]
      log "    - determine_druid(#{k})"
      self.pid = method("get_pid_from_#{k}").call
      self.druid = DruidTools::Druid.new(pid)
    end

    def get_pid_from_manifest
      manifest_row[:druid]
    end

    def get_pid_from_suri
      with_retries(max_tries: Dor::Config.dor.num_attempts, rescue: Exception, handler: PreAssembly.retry_handler('GET_PID_FROM_SURI', method(:log))) do
        result = Dor::SuriService.mint_id
        raise PreAssembly::UnknownError unless result.class == String
        result
      end
    end

    def get_pid_from_druid_minter
      DruidMinter.next
    end

    def get_pid_from_container
      "druid:#{container_basename}"
    end

    def get_pid_from_container_barcode
      query_dor_by_barcode(container_basename).each do |id|
        @pid = id
        return id if apo_matches_exactly_one?(get_dor_item_apos.map(&:pid))
      end
      nil
    end

    def query_dor_by_barcode(barcode)
      Dor::SearchService.query_by_id :barcode => barcode
    end

    def get_dor_item_apos(_pid)
      dor_object.nil? ? [] : dor_object.admin_policy_object
    end

    def dor_object
      @dor_object ||= Dor::Item.find(pid)
    rescue ActiveFedora::ObjectNotFoundError
      @dor_object = nil
    end

    def content_type_tag
      dor_object.nil? ? "" : dor_object.content_type_tag
    end

    def apo_matches_exactly_one?(apo_pids)
      n = 0
      apo_pids.each { |pid| n += 1 if pid == @apo_druid_id }
      n == 1
    end

    def container_basename
      File.basename(container)
    end

    ####
    # Registration and other Dor interactions.
    ####

    def register
      return unless project_style[:should_register]
      log "    - register(#{pid})"
      self.dor_object      = register_in_dor(registration_params)
      self.reg_by_pre_assembly = true
    end

    def register_in_dor(params)
      with_retries(max_tries: Dor::Config.dor.num_attempts, rescue: Exception, handler: PreAssembly.retry_handler('REGISTER_IN_DOR', method(:log), params)) do
        result = begin
          Dor::RegistrationService.register_object params
        rescue Exception => e
          source_id = "#{project_name}:#{source_id}"
          log "      ** REGISTER FAILED ** with '#{e.message}' ... deleting object #{pid} and source id #{source_id} and trying attempt #{i} of #{Dor::Config.dor.num_attempts} in #{Dor::Config.dor.sleep_time} seconds"
          delete_objects_from_workspace_by_source_id(source_id)
          nil
        end

        raise PreAssembly::UnknownError unless result.class == Dor::Item
        result
      end
    end

    def delete_objects_from_workspace_by_source_id(source_id)
      sourceid_pids = Dor::SearchService.query_by_id(source_id)
      all_pids = sourceid_pids << pid
      all_pids.each do |pid|
        begin
          Dor::SearchService.solr.delete_by_id(pid) # should be unnecessary, but handles an edge case where the object is not in Fedora, but is in Solr
          Dor::Config.fedora.client["objects/#{pid}"].delete
        rescue Exception => e
          log "      ... could not delete object with #{pid} or source id #{source_id} : #{e.message} ..."
        end
      end
      Dor::SearchService.solr.commit
    end

    def registration_params
      tags = ["Project : #{project_name}"]
      tags << apply_tag unless apply_tag.blank?
      {
        :object_type  => 'item',
        :admin_policy => apo_druid_id,
        :source_id    => { project_name => source_id },
        :pid          => pid,
        :label        => label.blank? ? Dor::Config.dor.default_label : label,
        :tags         => tags,
      }
    end

    def add_dor_object_to_set
      # Add the object to a set (a sub-collection).
      return unless set_druid_id && project_style[:should_register]
      log "    - add_dor_object_to_set(#{set_druid_id})"

      with_retries(max_tries: Dor::Config.dor.num_attempts, rescue: Exception, handler: PreAssembly.retry_handler('ADD_DOR_OBJECT_TO_SET', method(:log))) do
        Array(set_druid_id).each do |druid|
          dor_object.add_relationship *add_member_relationship_params(druid)
          dor_object.add_relationship *add_collection_relationship_params(druid)
        end
        raise PreAssembly::UnknownError unless dor_object.save
      end
    end

    def add_member_relationship_params(druid)
      [:is_member_of, "info:fedora/#{druid}"]
    end

    def add_collection_relationship_params(druid)
      [:is_member_of_collection, "info:fedora/#{druid}"]
    end

    # Used during a re-accession, will remove symlinks in /dor/workspace, files from the stacks and content in /dor/assembly, workflows
    # but will not unregister the object
    def prepare_for_reaccession
      log "  - prepare_for_reaccession(#{druid})"
      Assembly::Utils.cleanup_object(druid.druid, [:stacks, :stage, :symlinks])
    end

    # Used during testing and development work to unregister objects created in -dev.
    # Do not run unless the object was registered by pre-assembly.
    def unregister
      return unless reg_by_pre_assembly
      log "  - unregister(#{pid})"
      Assembly::Utils.unregister(pid)
      self.dor_object = nil
      self.reg_by_pre_assembly = false
    end

    ####
    # Staging files.
    ####

    # Create the druid tree within the staging directory,
    # and then copy-recursive all stageable items to that area.
    def stage_files
      log "    - staging(druid_tree_dir = #{druid_tree_dir.inspect})"
      create_object_directories
      stageable_items.each do |si_path|
        log "      - staging(#{si_path}, #{content_dir})", :debug
        # determine destination of staged file by looking to see if it is a known datastream XML file or not
        destination = METADATA_FILES.include?(File.basename(si_path).downcase) ? metadata_dir : content_dir
        stager si_path, destination
      end
    end

    # Technical metadata combined file for SMPL.
    def generate_technical_metadata
      create_technical_metadata
      write_technical_metadata
    end

    # create technical metadata for smpl projects only
    def create_technical_metadata
      return unless @content_md_creation[:style].to_s == 'smpl'

      tm = Nokogiri::XML::Document.new
      tm_node = Nokogiri::XML::Node.new("technicalMetadata", tm)
      tm_node['objectId'] = pid
      tm_node['datetime'] = Time.now.utc.strftime("%Y-%m-%d-T%H:%M:%SZ")
      tm << tm_node

      # find all technical metadata files and just append the xml to the combined technicalMetadata
      current_directory = Dir.pwd
      FileUtils.cd(File.join(bundle_dir, container_basename))
      Dir.glob("**/*_techmd.xml").sort.each do |filename|
        tech_md_xml = Nokogiri::XML(File.open(File.join(bundle_dir, container_basename, filename)))
        tm.root << tech_md_xml.root
      end
      FileUtils.cd(current_directory)
      self.technical_md_xml = tm.to_xml
    end

    # write technical metadata out to a file only if it exists
    def write_technical_metadata
      return if technical_md_xml.blank?

      file_name = File.join metadata_dir, @technical_md_file
      log "    - write_technical_metadata_xml(#{file_name})"
      create_object_directories
      File.open(file_name, 'w') { |fh| fh.puts technical_md_xml }
    end

    # Content metadata.
    def generate_content_metadata
      create_content_metadata
      write_content_metadata
    end

    # Invoke the contentMetadata creation method used by the project
    # The name of the method invoked must be "create_content_metadata_xml_#{content_md_creation--style}", as defined in the YAML configuration
    # Custom methods are defined in the project_specific.rb file
    # if we are not using a standard known style of content metadata generation, pass the task off to a custom method
    def create_content_metadata
      if !['default', 'filename', 'dpg', 'none'].include? @content_md_creation[:style].to_s
        self.content_md_xml = method("create_content_metadata_xml_#{@content_md_creation[:style]}").call
      elsif content_md_creation[:style].to_s != 'none' # and assuming we don't want any contentMetadata, then use the Assembly gem to generate CM
        # otherwise use the content metadata generation gem
        params = { :druid => druid.id, :objects => content_object_files, :add_exif => false, :bundle => content_md_creation[:style].to_sym, :style => content_md_creation_style }

        params.merge!(:add_file_attributes => true, :file_attributes => file_attr.stringify_keys) unless file_attr.nil?

        self.content_md_xml = Assembly::ContentMetadata.create_content_metadata(params)
      end
    end

    # write content metadata out to a file
    def write_content_metadata
      return if content_md_creation[:style].to_s == 'none'
      file_name = File.join(metadata_dir, content_md_file)
      log "    - write_content_metadata_xml(#{file_name})"
      create_object_directories

      File.open(file_name, 'w') { |fh| fh.puts content_md_xml }

      # NOTE: This is being skipped because it now removes empty nodes, and we need an a node like this: <file id="filename" /> when first starting with contentMetadat
      #        If this node gets removed, then nothing works.  - Peter Mangiafico, October 3, 2015
      # mods_xml_doc = Nokogiri::XML(@content_md_xml) # create a nokogiri doc
      # normalizer = Normalizer.new
      # normalizer.normalize_document(mods_xml_doc.root) # normalize it
      # File.open(file_name, 'w') { |fh| fh.puts mods_xml_doc.to_xml } # write out normalized result
    end

    # Object files that should be included in content metadata.
    def content_object_files
      object_files.reject { |ofile| ofile.exclude_from_content }.sort
    end

    ####
    # Descriptive metadata.
    ####

    def generate_desc_metadata
      # Do nothing for bundles that don't suppy a template.
      return unless desc_md_template_xml
      create_desc_metadata_xml
      write_desc_metadata
    end

    def create_desc_metadata_xml
      log "    - create_desc_metadata_xml()"

      # XML escape all of the entries in the manifest row so they won't break the XML
      manifest_row.each { |k, v| manifest_row[k] = Nokogiri::XML::Text.new(v, Nokogiri::XML('')).to_s if v }

      # ensure access with symbol or string keys
      self.manifest_row = manifest_row.with_indifferent_access

      # Run the XML template through ERB.
      self.desc_md_xml = ERB.new(desc_md_template_xml, nil, '>').result(binding)

      # The manifest_row is a hash, with column names as the key.
      # In the template, as a conviennce we allow users to put specific column placeholders inside
      # double brackets: "blah [[column_name]] blah".
      # Here we replace those placeholders with the corresponding value from the manifest row.
      manifest_row.each { |k, v| desc_md_xml.gsub! "[[#{k}]]", v.to_s.strip }
      true
    end

    def write_desc_metadata
      file_name = File.join(metadata_dir, desc_md_file)
      log "    - write_desc_metadata_xml(#{file_name})"
      create_object_directories
      File.open(file_name, 'w') { |fh| fh.puts desc_md_xml }
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
      return unless init_assembly_wf
      log "    - initialize_assembly_workflow()"
      url = assembly_workflow_url

      with_retries(max_tries: Dor::Config.dor.num_attempts, rescue: Exception, handler: PreAssembly.retry_handler('INITIALIZE_ASSEMBLY_WORKFLOW', method(:log))) do
        result = RestClient.post url, {}
        raise PreAssembly::UnknownError unless result && [200, 201, 202, 204].include?(result.code)
        result
      end
    end

    def assembly_workflow_url
      self.druid = pid.include?('druid') ? pid : "druid:#{pid}"
      "#{Dor::Config.dor_services.url}/objects/#{druid}/apo_workflows/assemblyWF"
    end
  end
end
