module PreAssembly
  class DigitalObject
    include PreAssembly::Logging

    attr_reader :bundle, :stageable_items, :object_files,
                :stager, :label, :pid, :source_id

    delegate :bundle_dir,
             :content_md_creation,
             :content_structure,
             :project_name,
             :media_manifest,
             to: :bundle

    attr_accessor :container,
                  :pre_assem_finished

    # @param [PreAssembly::Bundle] bundle
    # @param [String] container the identifier (non-namespaced)
    # @param [Array<String>] stageable_items items to stage
    # @param [Array<ObjectFile>] object_files path to files that are part of the object
    # @param [String] label The label for this object
    # @param [String] pid The identifier for the item
    # @param [String] source_id The source identifier
    # @param [Object] stager the implementation of how to stage an object
    # rubocop:disable Metrics/ParameterLists
    def initialize(bundle, container: nil, stageable_items: nil, object_files: nil,
                   label: nil, pid: nil, source_id: nil, stager:)
      @bundle = bundle
      @container = container
      @stageable_items = stageable_items
      @object_files = object_files
      @label = label
      @pid = pid
      @source_id = source_id
      @stager = stager
    end
    # rubocop:enable Metrics/ParameterLists

    # set this object's content_md_creation_style
    # @return [Symbol]
    def content_md_creation_style
      # map the content type tags set inside an object to content metadata creation styles supported by the assembly-objectfile gem
      # format is 'tag_value' => 'gem style name'
      content_type_tag_mapping = {
        'Image' => :simple_image,
        'File' => :file,
        'Book (flipbook, ltr)' => :simple_book,
        'Book (image-only)' => :book_as_image,
        'Manuscript (flipbook, ltr)' => :simple_book,
        'Manuscript (image-only)' => :book_as_image,
        'Map' => :map,
        '3D' => :'3d'
      }
      content_type_tag_mapping[content_type_tag] || content_structure.to_sym
    end

    ####
    # The main process.
    ####

    def pre_assemble
      log "  - pre_assemble(#{source_id}) started"
      raise "#{druid.druid} can't be opened for a new version; cannot re-accession when version > 1 unless object can be opened" if !openable? && current_object_version > 1
      @assembly_directory = AssemblyDirectory.create(druid_id: druid.id)
      stage_files
      generate_content_metadata
      generate_technical_metadata
      create_new_version if openable?
      initialize_assembly_workflow
      log "    - pre_assemble(#{pid}) finished"
    end

    attr_reader :assembly_directory

    ####
    # Determining the druid.
    ####

    # @return [DruidTools::Druid]
    def druid
      @druid ||= DruidTools::Druid.new(pid)
    end

    def dor_object
      @dor_object ||= Dor::Item.find(pid)
    rescue ActiveFedora::ObjectNotFoundError
      @dor_object = nil
    end

    def content_type_tag
      dor_object.nil? ? '' : dor_object.content_type_tag
    end

    def container_basename
      File.basename(container)
    end

    ####
    # Registration and other Dor interactions.
    ####

    def add_collection_relationship_params(druid)
      [:is_member_of_collection, "info:fedora/#{druid}"]
    end

    ####
    # Staging files.
    ####

    # Create the druid tree within the staging directory,
    # and then copy-recursive all stageable items to that area.
    def stage_files
      log "    - staging(druid_tree_dir = #{assembly_directory.druid_tree_dir.inspect})"
      stageable_items.each do |si_path|
        # determine destination of staged file by looking to see if it is a known datastream XML file or not
        destination = assembly_directory.path_for(si_path)
        log "      - staging(#{si_path}, #{destination})", :debug
        stager.stage si_path, destination
      end
    end

    # create technical metadata for media projects only
    def create_technical_metadata
      return unless content_md_creation == 'media_cm_style'

      tm = Nokogiri::XML::Document.new
      tm_node = Nokogiri::XML::Node.new('technicalMetadata', tm)
      tm_node['objectId'] = pid
      tm_node['datetime'] = Time.now.utc.strftime('%Y-%m-%d-T%H:%M:%SZ')
      tm << tm_node

      # find all technical metadata files and just append the xml to the combined technicalMetadata
      current_directory = Dir.pwd
      FileUtils.cd(File.join(bundle_dir, container_basename))
      Dir.glob('**/*_techmd.xml').sort.each do |filename|
        tech_md_xml = Nokogiri::XML(File.open(File.join(bundle_dir, container_basename, filename)))
        tm.root << tech_md_xml.root
      end
      FileUtils.cd(current_directory)
      tm.to_xml
    end

    # write technical metadata out for media projects
    def generate_technical_metadata
      technical_md_xml = create_technical_metadata
      return if technical_md_xml.blank?
      file_name = assembly_directory.technical_metadata_file
      log "    - write_technical_metadata_xml(#{file_name})"
      File.open(file_name, 'w') { |fh| fh.puts technical_md_xml }
    end

    # Write contentMetadata.xml file
    def generate_content_metadata
      File.open(assembly_directory.content_metadata_file, 'w') { |fh| fh.puts create_content_metadata }
    end

    # Invoke the contentMetadata creation method used by the project
    def create_content_metadata
      ContentMetadataCreator.new(druid_id: druid.id,
                                 content_md_creation: content_md_creation,
                                 object_files: object_files,
                                 content_md_creation_style: content_md_creation_style,
                                 media_manifest: media_manifest).create
    end

    # Checks filesystem for expected files
    def object_files_exist?
      return false if object_files.empty?
      object_files.map(&:path).all? { |path| File.readable?(path) }
    end

    ####
    # Versioning for a re-accession.
    ####

    def openable?
      Dor::Services::Client.object(druid.druid).version.openable?
    end

    def current_object_version
      @current_object_version ||= Dor::Services::Client.object(druid.druid).version.current.to_i
    end

    # When reaccessioning, we need to first open and close a version without kicking off accessionWF
    def create_new_version
      Dor::Services::Client.object(druid.druid).version.open(
        significance: 'major',
        description: 'pre-assembly re-accession',
        opening_user_name: bundle.bundle_context.user.sunet_id
      )
      Dor::Services::Client.object(druid.druid).version.close(start_accession: false)
    end

    ####
    # Initialize the assembly workflow.
    ####

    # Call web service to add assemblyWF to the object in DOR.
    def initialize_assembly_workflow
      Dor::Config.workflow.client.create_workflow_by_name(druid.druid, 'assemblyWF')
    end
  end
end
